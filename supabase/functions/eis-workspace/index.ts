// Gene - Nov, 24, 2026: Edge Function for workspace bootstrap, Auth/RBAC membership,
// dashboard aggregation, gateway config, and ERP webhook key management.
import type { SupabaseClient } from '@supabase/supabase-js';
import {
  HttpAuthError,
  requireAuthenticatedUser,
  requireWorkspaceAuth,
  sha256Hex,
} from '../_shared/auth.ts';
import { birAtcCatalog, fromCents, toCents } from '../_shared/bir_tax.ts';
import {
  errorResponse,
  handleCors,
  jsonResponse,
} from '../_shared/cors.ts';
import {
  appendAuditEntry,
  seedDemoDataForWorkspace,
} from '../_shared/invoice_pipeline.ts';

function slugWorkspaceCode(name: string): string {
  const base = name
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 14);
  const randBytes = crypto.getRandomValues(new Uint8Array(3));
  const suffix = Array.from(randBytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
    .toUpperCase();
  return `WS-${base || 'PH'}-${suffix}`;
}

async function findAuthUserIdByEmail(
  serviceClient: SupabaseClient,
  targetEmail: string,
): Promise<{ id: string; email: string } | null> {
  const normalized = targetEmail.trim().toLowerCase();
  let page = 1;
  while (page <= 10) {
    const { data, error } = await serviceClient.auth.admin.listUsers({
      page,
      perPage: 200,
    });
    if (error || !data?.users?.length) break;
    const match = data.users.find(
      (u) => (u.email ?? '').trim().toLowerCase() === normalized,
    );
    if (match) {
      return { id: match.id, email: match.email ?? targetEmail.trim() };
    }
    if (data.users.length < 200) break;
    page += 1;
  }
  return null;
}

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const action = String(body['action'] ?? 'me');
    const requestedWorkspaceId =
      body['workspaceId'] != null ? String(body['workspaceId']) : null;

    if (action === 'bootstrap') {
      const { user, serviceClient } = await requireAuthenticatedUser(req);
      const workspaceName = String(
        body['workspaceName'] ?? 'Philippine Enterprise Compliance Hub',
      ).trim();
      const seedDemo = body['seedDemo'] !== false;
      const email = user.email ?? `${user.id}@eis.local`;

      // Reuse first workspace if user already belongs to one and explicitly passed reuseExisting.
      if (body['reuseExisting'] === true) {
        const { data: existing } = await serviceClient
          .from('workspace_members')
          .select('workspace_id, role, email, workspaces(id, code, name)')
          .eq('user_id', user.id)
          .order('created_at', { ascending: true })
          .limit(1)
          .maybeSingle();
        if (existing) {
          return jsonResponse({
            workspace: existing.workspaces,
            membership: {
              workspaceId: existing.workspace_id,
              role: existing.role,
              email: existing.email,
            },
          });
        }
      }

      const code = slugWorkspaceCode(workspaceName);
      const { data: ws, error: wsErr } = await serviceClient
        .from('workspaces')
        .insert({
          code,
          name: workspaceName,
          created_by: user.id,
        })
        .select('*')
        .single();

      if (wsErr || !ws) {
        return errorResponse(`Failed to create workspace: ${wsErr?.message}`, 500);
      }

      const { error: memErr } = await serviceClient
        .from('workspace_members')
        .insert({
          workspace_id: ws.id,
          user_id: user.id,
          email,
          role: 'admin',
        });

      if (memErr) {
        return errorResponse(`Failed to create admin membership: ${memErr.message}`, 500);
      }

      const { error: gwErr } = await serviceClient
        .from('gateway_configs')
        .insert({
          workspace_id: ws.id,
          mode: 'MOCK_BIR_SIMULATOR',
          simulate_outage: false,
          updated_by: user.id,
        });

      if (gwErr) {
        return errorResponse(`Failed to create gateway config: ${gwErr.message}`, 500);
      }

      if (seedDemo) {
        await seedDemoDataForWorkspace(serviceClient, {
          workspaceId: String(ws.id),
          actorId: user.id,
          actor: email,
        });
      }

      return jsonResponse({
        workspace: {
          id: ws.id,
          code: ws.code,
          name: ws.name,
        },
        membership: {
          workspaceId: ws.id,
          workspaceCode: ws.code,
          workspaceName: ws.name,
          role: 'admin',
          email,
        },
      });
    }

    if (action === 'me') {
      const { user, serviceClient } = await requireAuthenticatedUser(req);
      const { data: memberships, error } = await serviceClient
        .from('workspace_members')
        .select('id, workspace_id, role, email, workspaces(id, code, name)')
        .eq('user_id', user.id)
        .order('created_at', { ascending: true });

      if (error) {
        return errorResponse(`Failed to load memberships: ${error.message}`, 500);
      }

      const items = (memberships ?? []).map((m) => {
        const ws = (m.workspaces ?? {}) as Record<string, unknown>;
        return {
          workspaceId: m.workspace_id,
          workspaceCode: String(ws['code'] ?? ''),
          workspaceName: String(ws['name'] ?? ''),
          role: m.role,
          email: m.email,
        };
      });

      const activeId = requestedWorkspaceId ?? items[0]?.workspaceId ?? null;
      let roster: Array<Record<string, unknown>> = [];
      if (activeId && items.some((i) => i.workspaceId === activeId)) {
        const { data: members } = await serviceClient
          .from('workspace_members')
          .select('id, user_id, email, role, created_at')
          .eq('workspace_id', activeId)
          .order('created_at', { ascending: true });
        roster = (members ?? []).map((r) => ({
          id: r.id,
          userId: r.user_id,
          email: r.email,
          role: r.role,
          createdAt: r.created_at,
        }));
      }

      return jsonResponse({
        userId: user.id,
        email: user.email ?? '',
        workspaces: items,
        members: roster,
      });
    }

    if (action === 'upsert_member') {
      const ctx = await requireWorkspaceAuth(req, {
        workspaceId: requestedWorkspaceId,
        allowedRoles: ['admin'],
      });
      const email = String(body['email'] ?? '').trim();
      const role = String(body['role'] ?? 'accountant').trim();
      const validRoles = [
        'admin',
        'accountant',
        'cashier',
        'auditor',
        'security_officer',
      ];
      if (!email || !validRoles.includes(role)) {
        return errorResponse(
          'Valid email and role (admin, accountant, cashier, auditor, security_officer) are required.',
          400,
        );
      }

      const foundUser = await findAuthUserIdByEmail(ctx.serviceClient, email);
      if (!foundUser) {
        return errorResponse(
          `No Supabase Auth user found for ${email}. Ask them to sign up first, then assign their workspace role.`,
          404,
        );
      }

      const { data: upserted, error: upsErr } = await ctx.serviceClient
        .from('workspace_members')
        .upsert(
          {
            workspace_id: ctx.workspaceId,
            user_id: foundUser.id,
            email: foundUser.email,
            role,
          },
          { onConflict: 'workspace_id,user_id' },
        )
        .select('id, user_id, email, role, created_at')
        .single();

      if (upsErr || !upserted) {
        return errorResponse(`Failed to upsert member: ${upsErr?.message}`, 500);
      }

      const { data: firstTp } = await ctx.serviceClient
        .from('taxpayers')
        .select('tin')
        .eq('workspace_id', ctx.workspaceId)
        .limit(1)
        .maybeSingle();

      await appendAuditEntry(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        actorId: ctx.user.id,
        actor: ctx.actor,
        action: 'UPSERT_WORKSPACE_MEMBER',
        taxpayerTin: String(firstTp?.tin ?? '000000000'),
        entityType: 'WorkspaceMember',
        entityId: String(upserted.user_id),
        details: `Assigned role "${role}" to ${upserted.email}.`,
      });

      return jsonResponse({
        id: upserted.id,
        userId: upserted.user_id,
        email: upserted.email,
        role: upserted.role,
        createdAt: upserted.created_at,
      });
    }

    if (action === 'dashboard') {
      const ctx = await requireWorkspaceAuth(req, {
        workspaceId: requestedWorkspaceId,
      });
      const taxpayerId =
        body['taxpayerId'] != null ? String(body['taxpayerId']) : null;

      const [{ data: gw }, { count: taxpayerCount }, invRes, auditRes] =
        await Promise.all([
          ctx.serviceClient
            .from('gateway_configs')
            .select('mode, simulate_outage, cert_endpoint, prod_endpoint')
            .eq('workspace_id', ctx.workspaceId)
            .maybeSingle(),
          ctx.serviceClient
            .from('taxpayers')
            .select('id', { count: 'exact', head: true })
            .eq('workspace_id', ctx.workspaceId),
          (() => {
            let q = ctx.serviceClient
              .from('invoices')
              .select(
                'status, direction, doc_type, source_system, net_sales, vat_amt, withholding_tax_amt',
              )
              .eq('workspace_id', ctx.workspaceId);
            if (taxpayerId) q = q.eq('taxpayer_id', taxpayerId);
            return q;
          })(),
          ctx.serviceClient.rpc('verify_workspace_audit_trail', {
            p_workspace_id: ctx.workspaceId,
          }),
        ]);

      if (invRes.error) {
        return errorResponse(`Failed to load dashboard invoices: ${invRes.error.message}`, 500);
      }

      const invs = invRes.data ?? [];
      let transmitted = 0;
      let queuedRetry = 0;
      let rejected = 0;
      let totalSalesCents = 0;
      let totalOutputVatCents = 0;
      let totalCwtCents = 0;
      const bySource: Record<string, number> = {};

      for (const inv of invs) {
        if (inv.status === 'TRANSMITTED') transmitted += 1;
        else if (inv.status === 'QUEUED_RETRY') queuedRetry += 1;
        else if (inv.status === 'REJECTED') rejected += 1;

        if (inv.direction === 'SALES' && inv.doc_type !== '03') {
          totalSalesCents += toCents(Number(inv.net_sales ?? 0));
          totalOutputVatCents += toCents(Number(inv.vat_amt ?? 0));
        }
        totalCwtCents += toCents(Number(inv.withholding_tax_amt ?? 0));
        const src = String(inv.source_system ?? 'IES_UI');
        bySource[src] = (bySource[src] ?? 0) + 1;
      }

      const auditChain = (auditRes.data as Record<string, unknown> | null) ?? {
        valid: true,
        totalEntries: 0,
        brokenAtSeq: null,
      };

      return jsonResponse({
        gatewayConfig: {
          mode: String(gw?.mode ?? 'MOCK_BIR_SIMULATOR'),
          simulateOutage: gw?.simulate_outage === true,
          certEndpoint: String(
            gw?.cert_endpoint ??
              'https://eis-cert.bir.gov.ph/api/v2.01/invoices',
          ),
          prodEndpoint: String(
            gw?.prod_endpoint ?? 'https://eis.bir.gov.ph/api/v2.01/invoices',
          ),
        },
        taxpayerCount: taxpayerCount ?? 0,
        invoiceCounts: {
          total: invs.length,
          transmitted,
          queuedRetry,
          rejected,
        },
        financialsPhp: {
          totalSales: fromCents(totalSalesCents),
          totalOutputVat: fromCents(totalOutputVatCents),
          totalCwt: fromCents(totalCwtCents),
        },
        bySource,
        auditChain,
        atcCatalog: Object.values(birAtcCatalog),
      });
    }

    if (action === 'update_gateway_config') {
      const ctx = await requireWorkspaceAuth(req, {
        workspaceId: requestedWorkspaceId,
        allowedRoles: ['admin', 'security_officer'],
      });
      const { data: cur } = await ctx.serviceClient
        .from('gateway_configs')
        .select('*')
        .eq('workspace_id', ctx.workspaceId)
        .maybeSingle();

      const nextMode =
        body['mode'] != null
          ? String(body['mode'])
          : String(cur?.mode ?? 'MOCK_BIR_SIMULATOR');
      const nextOutage =
        typeof body['simulateOutage'] === 'boolean'
          ? (body['simulateOutage'] as boolean)
          : cur?.simulate_outage === true;

      const { data: updated, error: updErr } = await ctx.serviceClient
        .from('gateway_configs')
        .upsert(
          {
            workspace_id: ctx.workspaceId,
            mode: nextMode,
            simulate_outage: nextOutage,
            updated_by: ctx.user.id,
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'workspace_id' },
        )
        .select('*')
        .single();

      if (updErr || !updated) {
        return errorResponse(`Failed to update gateway config: ${updErr?.message}`, 500);
      }

      const { data: firstTp } = await ctx.serviceClient
        .from('taxpayers')
        .select('tin')
        .eq('workspace_id', ctx.workspaceId)
        .limit(1)
        .maybeSingle();

      await appendAuditEntry(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        actorId: ctx.user.id,
        actor: ctx.actor,
        action: 'UPDATE_BIR_GATEWAY',
        taxpayerTin: String(firstTp?.tin ?? '000000000'),
        entityType: 'GatewayConfig',
        entityId: nextMode,
        details: `Gateway Mode=${nextMode}, SimulateOutage=${nextOutage}`,
      });

      return jsonResponse({
        mode: updated.mode,
        simulateOutage: updated.simulate_outage,
        certEndpoint: updated.cert_endpoint,
        prodEndpoint: updated.prod_endpoint,
      });
    }

    if (action === 'create_webhook_key') {
      const ctx = await requireWorkspaceAuth(req, {
        workspaceId: requestedWorkspaceId,
        allowedRoles: ['admin', 'security_officer'],
      });
      const connector = String(body['connector'] ?? 'generic_pos');
      const label = String(body['label'] ?? `${connector} integration`).trim();
      const rawBytes = crypto.getRandomValues(new Uint8Array(24));
      const rawHex = Array.from(rawBytes)
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('');
      const apiKey = `eis_wh_${rawHex}`;
      const keyHash = await sha256Hex(apiKey);
      const keyPrefix = apiKey.slice(0, 14);

      const { error } = await ctx.serviceClient.from('erp_webhook_keys').insert({
        workspace_id: ctx.workspaceId,
        connector,
        label,
        key_prefix: keyPrefix,
        key_hash: keyHash,
        is_active: true,
        created_by: ctx.user.id,
      });

      if (error) {
        return errorResponse(`Failed to create webhook key: ${error.message}`, 500);
      }

      const { data: firstTp } = await ctx.serviceClient
        .from('taxpayers')
        .select('tin')
        .eq('workspace_id', ctx.workspaceId)
        .limit(1)
        .maybeSingle();

      await appendAuditEntry(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        actorId: ctx.user.id,
        actor: ctx.actor,
        action: 'CREATE_WEBHOOK_KEY',
        taxpayerTin: String(firstTp?.tin ?? '000000000'),
        entityType: 'ErpWebhookKey',
        entityId: keyPrefix,
        details: `Created scoped ${connector} webhook API key (${label}, prefix ${keyPrefix}).`,
      });

      return jsonResponse({
        apiKey,
        keyPrefix,
        connector,
        label,
      }, 201);
    }

    return errorResponse(`Unsupported workspace action: ${action}`, 400);
  } catch (err) {
    if (err instanceof HttpAuthError) {
      return errorResponse(err.message, err.status);
    }
    return errorResponse(
      err instanceof Error ? err.message : String(err),
      500,
    );
  }
});
