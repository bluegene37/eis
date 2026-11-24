// Gene - Nov, 24, 2026: Edge Function for BIR EIS v2.01 invoice issuance, Credit Memo (DocType 03),
// and manual 3-day SLA retry queue flush.
import { HttpAuthError, requireWorkspaceAuth } from '../_shared/auth.ts';
import {
  type BirEisPayloadV201,
  parseCanonicalIngestInput,
} from '../_shared/bir_tax.ts';
import { errorResponse, handleCors, jsonResponse } from '../_shared/cors.ts';
import {
  ingestAndTransmitInvoice,
  processWorkspaceRetryQueue,
} from '../_shared/invoice_pipeline.ts';

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const action = String(body['action'] ?? 'create');
    const workspaceId =
      body['workspaceId'] != null ? String(body['workspaceId']) : null;

    if (action === 'create') {
      const ctx = await requireWorkspaceAuth(req, {
        workspaceId,
        allowedRoles: ['admin', 'accountant', 'cashier'],
      });
      const payload =
        (body['payload'] as Record<string, unknown> | undefined) ?? body;
      const forceInvalid = payload['forceInvalidPayload'] === true;
      const record = await ingestAndTransmitInvoice(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        actorId: ctx.user.id,
        actor: ctx.actor,
        input: parseCanonicalIngestInput(payload),
        forceInvalidPayload: forceInvalid,
      });
      return jsonResponse(record);
    }

    if (action === 'credit_memo') {
      const ctx = await requireWorkspaceAuth(req, {
        workspaceId,
        allowedRoles: ['admin', 'accountant'],
      });
      const invoiceId = String(body['invoiceId'] ?? '').trim();
      const reason = String(
        body['reason'] ?? 'Sales Return / Price Adjustment',
      );
      if (!invoiceId) {
        return errorResponse('invoiceId is required.', 400);
      }

      const { data: orig, error } = await ctx.serviceClient
        .from('invoices')
        .select('*')
        .eq('id', invoiceId)
        .eq('workspace_id', ctx.workspaceId)
        .maybeSingle();

      if (error || !orig) {
        return errorResponse(`Invoice ${invoiceId} not found.`, 404);
      }

      const p = orig.payload as BirEisPayloadV201;
      const cm = await ingestAndTransmitInvoice(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        actorId: ctx.user.id,
        actor: ctx.actor,
        input: {
          taxpayerId: String(orig.taxpayer_id),
          branchCd: String(orig.branch_cd),
          sourceSystem: 'IES_UI',
          systemType: p.SystemType,
          docType: '03',
          transClass: p.TransClass,
          direction: String(orig.direction),
          isPaid: orig.is_paid === true,
          corrYN: 'Y',
          refEisUniqueId: p.EisUniqueId,
          buyerName: p.Buyer.RegNm,
          buyerTin: p.Buyer.TIN,
          buyerBranchCd: p.Buyer.BranchCd,
          buyerCategory: p.Buyer.BuyerCategory,
          osacaPwdId: p.Buyer.OsacaPwdId ?? null,
          buyerAddress: p.Buyer.Address,
          items: p.ItemList.map((i) => ({
            itemCd: i.ItemCd,
            itemNm: `${i.ItemNm} (${reason})`,
            unit: i.Unit,
            qty: i.Qty,
            unitPrice: i.UnitCost,
            taxClassification: i.TaxClassification,
            regularDiscountAmt: i.DiscountAmt,
            atcCode: i.AtcCode,
          })),
          otherChargesAmt: 0,
        },
      });
      return jsonResponse(cm);
    }

    if (action === 'retry_queue') {
      const ctx = await requireWorkspaceAuth(req, {
        workspaceId,
        allowedRoles: ['admin', 'accountant'],
      });
      const res = await processWorkspaceRetryQueue(ctx.serviceClient, {
        workspaceId: ctx.workspaceId,
        actorId: ctx.user.id,
        actor: ctx.actor,
        dueOnly: false,
      });
      return jsonResponse(res);
    }

    return errorResponse(`Unsupported invoice action: ${action}`, 400);
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
