// Gene - Nov, 24, 2026: Edge Function for Multi-TIN taxpayer registration, branch setup,
// and private-vault RSA-2048 JWS / AES-256-GCM key rotation.
import { HttpAuthError, requireWorkspaceAuth } from '../_shared/auth.ts';
import { errorResponse, handleCors, jsonResponse } from '../_shared/cors.ts';
import {
  addTaxpayerBranch,
  registerTaxpayerWithKeys,
  rotateTaxpayerVaultKeys,
} from '../_shared/invoice_pipeline.ts';

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const action = String(body['action'] ?? 'register');
    const workspaceId =
      body['workspaceId'] != null ? String(body['workspaceId']) : null;

    if (action === 'register') {
      const ctx = await requireWorkspaceAuth(req, {
        workspaceId,
        allowedRoles: ['admin', 'accountant'],
      });
      const created = await registerTaxpayerWithKeys(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        actorId: ctx.user.id,
        actor: ctx.actor,
        tin: String(body['tin'] ?? ''),
        taxType: String(body['taxType'] ?? 'VAT'),
        registeredName: String(body['registeredName'] ?? ''),
        businessName: String(body['businessName'] ?? ''),
        email: String(body['email'] ?? ''),
        eisCertId:
          body['eisCertId'] != null ? String(body['eisCertId']) : null,
        pttNumber:
          body['pttNumber'] != null ? String(body['pttNumber']) : null,
        headOfficeAddress:
          (body['headOfficeAddress'] as Record<string, unknown> | undefined) ??
          null,
      });
      return jsonResponse(created, 201);
    }

    if (action === 'add_branch') {
      const ctx = await requireWorkspaceAuth(req, {
        workspaceId,
        allowedRoles: ['admin', 'accountant'],
      });
      const taxpayerId = String(body['taxpayerId'] ?? '').trim();
      if (!taxpayerId) {
        return errorResponse('taxpayerId is required.', 400);
      }
      const branch = await addTaxpayerBranch(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        taxpayerId,
        actorId: ctx.user.id,
        actor: ctx.actor,
        branchCd: String(body['branchCd'] ?? '0001'),
        branchName: String(body['branchName'] ?? 'Branch'),
        address:
          (body['address'] as Record<string, unknown> | undefined) ?? null,
        invoicePrefix:
          body['invoicePrefix'] != null ? String(body['invoicePrefix']) : null,
      });
      return jsonResponse(branch, 201);
    }

    if (action === 'rotate_keys') {
      const ctx = await requireWorkspaceAuth(req, {
        workspaceId,
        allowedRoles: ['admin', 'security_officer'],
      });
      const taxpayerId = String(body['taxpayerId'] ?? '').trim();
      if (!taxpayerId) {
        return errorResponse('taxpayerId is required.', 400);
      }
      const rotated = await rotateTaxpayerVaultKeys(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        taxpayerId,
        actorId: ctx.user.id,
        actor: ctx.actor,
      });
      return jsonResponse(rotated);
    }

    return errorResponse(`Unsupported taxpayer action: ${action}`, 400);
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
