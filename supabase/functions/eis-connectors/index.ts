// Gene - Nov, 24, 2026: Edge Function for Xero, QuickBooks, Odoo, and CSV batch ERP ingestion
// supporting both authenticated users (admin/accountant) and scoped X-EIS-API-Key webhooks.
import { HttpAuthError, verifyWebhookOrUserAuth } from '../_shared/auth.ts';
import { errorResponse, handleCors, jsonResponse } from '../_shared/cors.ts';
import {
  mapOdooToCanonical,
  mapQuickBooksToCanonical,
  mapXeroToCanonical,
  parseCsvBatchToCanonical,
} from '../_shared/erp_mappers.ts';
import { ingestAndTransmitInvoice } from '../_shared/invoice_pipeline.ts';

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const url = new URL(req.url);
    const action = String(
      body['action'] ??
        body['connector'] ??
        url.searchParams.get('connector') ??
        '',
    ).toLowerCase();
    const workspaceId =
      body['workspaceId'] != null ? String(body['workspaceId']) : null;
    const taxpayerId =
      body['taxpayerId'] != null ? String(body['taxpayerId']) : null;

    if (!['xero', 'quickbooks', 'odoo', 'csv'].includes(action)) {
      return errorResponse(
        `Unsupported connector action: "${action}". Expected xero, quickbooks, odoo, or csv.`,
        400,
      );
    }

    const ctx = await verifyWebhookOrUserAuth(req, action, workspaceId);

    if (action === 'csv') {
      const csvText = String(body['csv'] ?? '');
      const items = parseCsvBatchToCanonical(csvText, taxpayerId);
      const records: Array<Record<string, unknown>> = [];
      for (const item of items) {
        records.push(
          await ingestAndTransmitInvoice(ctx.serviceClient, {
            workspaceId: ctx.workspaceId,
            actorId: ctx.actorId,
            actor: ctx.actor,
            input: item,
          }),
        );
      }
      return jsonResponse({
        importedCount: records.length,
        records,
      });
    }

    const payload =
      (body['payload'] as Record<string, unknown> | undefined) ?? body;
    const canonical =
      action === 'xero'
        ? mapXeroToCanonical(payload, taxpayerId)
        : action === 'quickbooks'
        ? mapQuickBooksToCanonical(payload, taxpayerId)
        : mapOdooToCanonical(payload, taxpayerId);

    const record = await ingestAndTransmitInvoice(ctx.serviceClient, {
      workspaceId: ctx.workspaceId,
      actorId: ctx.actorId,
      actor: ctx.actor,
      input: canonical,
    });
    return jsonResponse(record);
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
