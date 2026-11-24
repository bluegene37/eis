// Gene - Nov, 24, 2026: Supabase JWT, Workspace RBAC, and scoped ERP webhook API-key verification.
import { createClient, type SupabaseClient, type User } from '@supabase/supabase-js';

export type EisUserRole =
  | 'admin'
  | 'accountant'
  | 'cashier'
  | 'auditor'
  | 'security_officer';

export interface WorkspaceMemberRow {
  id: string;
  workspace_id: string;
  user_id: string;
  email: string;
  role: EisUserRole;
}

export interface AuthContext {
  user: User;
  member: WorkspaceMemberRow;
  workspaceId: string;
  actor: string;
  serviceClient: SupabaseClient;
}

export interface WebhookOrUserAuthContext {
  workspaceId: string;
  actorId: string | null;
  actor: string;
  serviceClient: SupabaseClient;
}

export function createServiceClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in Edge Function environment.');
  }
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

export class HttpAuthError extends Error {
  readonly status: number;
  constructor(message: string, status = 401) {
    super(message);
    this.status = status;
  }
}

export async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export async function requireAuthenticatedUser(
  req: Request,
): Promise<{ user: User; serviceClient: SupabaseClient }> {
  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length).trim()
    : '';
  if (!token) {
    throw new HttpAuthError('Missing Authorization Bearer token.', 401);
  }

  const serviceClient = createServiceClient();
  const { data, error } = await serviceClient.auth.getUser(token);
  if (error || !data?.user) {
    throw new HttpAuthError('Invalid or expired authentication session.', 401);
  }
  return { user: data.user, serviceClient };
}

export async function requireWorkspaceAuth(
  req: Request,
  options?: {
    workspaceId?: string | null;
    allowedRoles?: EisUserRole[];
  },
): Promise<AuthContext> {
  const { user, serviceClient } = await requireAuthenticatedUser(req);
  const requestedWorkspaceId = options?.workspaceId?.trim();

  let query = serviceClient
    .from('workspace_members')
    .select('id, workspace_id, user_id, email, role')
    .eq('user_id', user.id);

  if (requestedWorkspaceId) {
    query = query.eq('workspace_id', requestedWorkspaceId);
  } else {
    query = query.order('created_at', { ascending: true }).limit(1);
  }

  const { data, error } = await query.maybeSingle();
  if (error) {
    throw new HttpAuthError(`Failed to verify workspace membership: ${error.message}`, 500);
  }
  if (!data) {
    throw new HttpAuthError(
      requestedWorkspaceId
        ? 'You are not a member of the requested workspace.'
        : 'No workspace membership found. Create or join a workspace first.',
      403,
    );
  }

  const member = data as WorkspaceMemberRow;
  if (
    options?.allowedRoles &&
    options.allowedRoles.length > 0 &&
    !options.allowedRoles.includes(member.role)
  ) {
    throw new HttpAuthError(
      `Role "${member.role}" is not permitted for this action. Required: ${options.allowedRoles.join(', ')}.`,
      403,
    );
  }

  return {
    user,
    member,
    workspaceId: member.workspace_id,
    actor: user.email ?? member.email ?? user.id,
    serviceClient,
  };
}

export async function verifyWebhookOrUserAuth(
  req: Request,
  connector: string,
  workspaceId?: string | null,
): Promise<WebhookOrUserAuthContext> {
  const apiKey = req.headers.get('x-eis-api-key')?.trim();
  if (apiKey) {
    const serviceClient = createServiceClient();
    const hash = await sha256Hex(apiKey);
    const { data, error } = await serviceClient
      .from('erp_webhook_keys')
      .select('id, workspace_id, connector, label, is_active, created_by')
      .eq('key_hash', hash)
      .eq('is_active', true)
      .maybeSingle();

    if (error || !data) {
      throw new HttpAuthError('Invalid or revoked X-EIS-API-Key.', 401);
    }
    if (
      data.connector !== connector &&
      data.connector !== 'generic_pos'
    ) {
      throw new HttpAuthError(
        `API key is scoped to connector "${data.connector}", not "${connector}".`,
        403,
      );
    }
    if (workspaceId && workspaceId !== data.workspace_id) {
      throw new HttpAuthError('API key does not belong to target workspace.', 403);
    }
    return {
      workspaceId: data.workspace_id as string,
      actorId: (data.created_by as string | null) ?? null,
      actor: `webhook.${connector}:${data.label}`,
      serviceClient,
    };
  }

  const ctx = await requireWorkspaceAuth(req, {
    workspaceId,
    allowedRoles: ['admin', 'accountant'],
  });
  return {
    workspaceId: ctx.workspaceId,
    actorId: ctx.user.id,
    actor: ctx.actor,
    serviceClient: ctx.serviceClient,
  };
}
