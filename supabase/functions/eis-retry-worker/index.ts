// Gene - Nov, 24, 2026: Scheduled Edge Function invoked by pg_cron / external scheduler
// to flush due QUEUED_RETRY invoices within the BIR 3-calendar-day SLA window.
import { createServiceClient } from '../_shared/auth.ts';
import { errorResponse, handleCors, jsonResponse } from '../_shared/cors.ts';
import { processWorkspaceRetryQueue } from '../_shared/invoice_pipeline.ts';

function timingSafeEquals(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  if (ab.length !== bb.length) return false;
  let diff = 0;
  for (let i = 0; i < ab.length; i++) {
    diff |= ab[i] ^ bb[i];
  }
  return diff === 0;
}

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const expectedSecret = Deno.env.get('EIS_CRON_SECRET')?.trim() ?? '';
    if (!expectedSecret) {
      return errorResponse(
        'EIS_CRON_SECRET is not configured on eis-retry-worker.',
        500,
      );
    }

    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.slice('Bearer '.length).trim()
      : '';
    if (!token || !timingSafeEquals(token, expectedSecret)) {
      return errorResponse('Unauthorized cron invocation.', 401);
    }

    const serviceClient = createServiceClient();
    const result = await processWorkspaceRetryQueue(serviceClient, {
      dueOnly: true,
      actor: 'worker.pg_cron',
    });

    return jsonResponse({
      status: 'ok',
      ...result,
    });
  } catch (err) {
    return errorResponse(
      err instanceof Error ? err.message : String(err),
      500,
    );
  }
});
