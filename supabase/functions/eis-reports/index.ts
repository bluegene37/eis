// Gene - Nov, 24, 2026: Edge Function for BIR Statutory Reports (RELIEF SLSP, SAWT, QAP 1601-EQ, Form 2307)
// with optional archival to private Supabase Storage (`eis-exports`).
import type { SupabaseClient } from '@supabase/supabase-js';
import { HttpAuthError, requireWorkspaceAuth } from '../_shared/auth.ts';
import type { BirAddress, BirEisPayloadV201 } from '../_shared/bir_tax.ts';
import { errorResponse, handleCors, jsonResponse } from '../_shared/cors.ts';
import { appendAuditEntry } from '../_shared/invoice_pipeline.ts';
import {
  generateBirForm2307,
  generateSlspReport,
  generateWithholdingDatReport,
} from '../_shared/statutory_reports.ts';

async function loadTaxpayerWithAddress(
  serviceClient: SupabaseClient,
  workspaceId: string,
  requestedTaxpayerId?: string | null,
) {
  let q = serviceClient
    .from('taxpayers')
    .select('id, tin, registered_name, business_name')
    .eq('workspace_id', workspaceId);
  if (requestedTaxpayerId) q = q.eq('id', requestedTaxpayerId);
  else q = q.order('created_at', { ascending: true }).limit(1);

  const { data: tp, error } = await q.maybeSingle();
  if (error || !tp) {
    throw new Error('Taxpayer profile not found in workspace.');
  }

  const { data: br } = await serviceClient
    .from('taxpayer_branches')
    .select('address')
    .eq('taxpayer_id', tp.id)
    .order('branch_cd', { ascending: true })
    .limit(1)
    .maybeSingle();

  return {
    id: String(tp.id),
    tin: String(tp.tin),
    registered_name: String(tp.registered_name),
    business_name: String(tp.business_name),
    head_office_address: (br?.address as BirAddress | null) ?? null,
  };
}

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const action = String(body['action'] ?? 'slsp');
    const workspaceId =
      body['workspaceId'] != null ? String(body['workspaceId']) : null;
    const taxpayerId =
      body['taxpayerId'] != null ? String(body['taxpayerId']) : null;
    const archiveToStorage = body['archiveToStorage'] === true;

    const ctx = await requireWorkspaceAuth(req, {
      workspaceId,
      allowedRoles: ['admin', 'accountant', 'auditor'],
    });

    if (action === 'form2307') {
      const invoiceId = String(body['invoiceId'] ?? '').trim();
      if (!invoiceId) {
        return errorResponse('invoiceId is required.', 400);
      }
      const { data: inv, error } = await ctx.serviceClient
        .from('invoices')
        .select('taxpayer_id, payload')
        .eq('id', invoiceId)
        .eq('workspace_id', ctx.workspaceId)
        .maybeSingle();

      if (error || !inv) {
        return errorResponse(`Invoice ${invoiceId} not found.`, 404);
      }

      const payload = inv.payload as BirEisPayloadV201;
      const report = generateBirForm2307(payload);

      if (archiveToStorage && report['printableHtml']) {
        const path = `${ctx.workspaceId}/${inv.taxpayer_id}/FORM2307-${payload.CompInvoiceId}.html`;
        await ctx.serviceClient.storage
          .from('eis-exports')
          .upload(path, String(report['printableHtml']), {
            contentType: 'text/html',
            upsert: true,
          });
      }

      return jsonResponse(report);
    }

    const tp = await loadTaxpayerWithAddress(
      ctx.serviceClient,
      ctx.workspaceId,
      taxpayerId,
    );

    const { data: invRows, error: invErr } = await ctx.serviceClient
      .from('invoices')
      .select('direction, payload')
      .eq('workspace_id', ctx.workspaceId)
      .eq('taxpayer_id', tp.id)
      .order('created_at', { ascending: false });

    if (invErr) {
      return errorResponse(`Failed to query invoices: ${invErr.message}`, 500);
    }

    const records = (invRows ?? []).map((r) => ({
      direction: String(r.direction),
      payload: r.payload as BirEisPayloadV201,
    }));

    if (action === 'slsp') {
      const kind = String(body['kind'] ?? 'SALES');
      const period = String(body['period'] ?? '202611');
      const report = generateSlspReport(tp, records, kind, period);

      await appendAuditEntry(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        actorId: ctx.user.id,
        actor: ctx.actor,
        action: `EXPORT_SLSP_${kind}`,
        taxpayerTin: tp.tin,
        entityType: 'StatutoryReport',
        entityId: String(report['filename']),
        details: `Generated BIR RELIEF SLSP (${kind}) ${report['filename']} with ${report['rowCount']} record(s).`,
      });

      if (archiveToStorage) {
        const path = `${ctx.workspaceId}/${tp.id}/${report['filename']}`;
        await ctx.serviceClient.storage
          .from('eis-exports')
          .upload(path, String(report['datContent']), {
            contentType: 'text/plain',
            upsert: true,
          });
      }

      return jsonResponse(report);
    }

    if (action === 'withholding') {
      const kind = String(body['kind'] ?? 'SAWT');
      const period = String(body['period'] ?? '202612');
      const report = generateWithholdingDatReport(tp, records, kind, period);

      await appendAuditEntry(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        actorId: ctx.user.id,
        actor: ctx.actor,
        action: `EXPORT_${kind}_DAT`,
        taxpayerTin: tp.tin,
        entityType: 'StatutoryReport',
        entityId: String(report['filename']),
        details: `Generated BIR ${kind} ${report['filename']} with ${report['rowCount']} record(s).`,
      });

      if (archiveToStorage) {
        const path = `${ctx.workspaceId}/${tp.id}/${report['filename']}`;
        await ctx.serviceClient.storage
          .from('eis-exports')
          .upload(path, String(report['datContent']), {
            contentType: 'text/plain',
            upsert: true,
          });
      }

      return jsonResponse(report);
    }

    return errorResponse(`Unsupported report action: ${action}`, 400);
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
