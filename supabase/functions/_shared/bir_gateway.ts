// Gene - Nov, 24, 2026: 3-Tier BIR EIS Gateway & Built-in Spec-Faithful Certification Simulator
// with Postgres duplicate-EisUniqueId checks and optional BIR_EGRESS_PROXY_URL support.
import type { SupabaseClient } from '@supabase/supabase-js';
import {
  type BirEisPayloadV201,
  validateBirArithmetic,
  validateBirSchemaV201,
} from './bir_tax.ts';
import {
  type AesGcmEnvelope,
  decryptAes256Envelope,
  verifyBirPayloadJws,
} from './vault.ts';

export interface BirGatewayConfig {
  mode: string;
  simulateOutage: boolean;
  certEndpoint: string;
  prodEndpoint: string;
}

export interface BirGatewayReceipt {
  ackCode: string;
  accepted: boolean;
  birAckId: string | null;
  message: string;
  errors: string[];
  gatewayTier: string;
  processedAt: string;
  jwsThumbprint: string;
}

export interface GatewayTaxpayerInfo {
  tin: string;
  eisCertId: string;
  pttNumber: string;
  publicKeyJson: string;
  aesKeyHex: string;
}

function randomAckId(dateRef: string): string {
  const bytes = crypto.getRandomValues(new Uint8Array(4));
  const suffix = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
    .toUpperCase();
  const datePart = dateRef.slice(0, 10).replace(/-/g, '');
  return `BIR-ACK-${datePart}-${suffix}`;
}

export async function loadWorkspaceGatewayConfig(
  serviceClient: SupabaseClient,
  workspaceId: string,
): Promise<BirGatewayConfig> {
  const { data } = await serviceClient
    .from('gateway_configs')
    .select('mode, simulate_outage, cert_endpoint, prod_endpoint')
    .eq('workspace_id', workspaceId)
    .maybeSingle();

  return {
    mode: String(data?.mode ?? 'MOCK_BIR_SIMULATOR'),
    simulateOutage: data?.simulate_outage === true,
    certEndpoint: String(
      data?.cert_endpoint ?? 'https://eis-cert.bir.gov.ph/api/v2.01/invoices',
    ),
    prodEndpoint: String(
      data?.prod_endpoint ?? 'https://eis.bir.gov.ph/api/v2.01/invoices',
    ),
  };
}

export async function transmitEnvelope(
  serviceClient: SupabaseClient,
  config: BirGatewayConfig,
  envelope: AesGcmEnvelope,
  taxpayer: GatewayTaxpayerInfo,
  options?: { allowDuplicateCheck?: boolean },
): Promise<BirGatewayReceipt> {
  const allowDuplicateCheck = options?.allowDuplicateCheck !== false;
  const nowIso = new Date().toISOString();

  if (config.simulateOutage) {
    return {
      ackCode: 'NET503',
      accepted: false,
      birAckId: null,
      message:
        'BIR EIS Gateway unreachable (simulated 503 maintenance window). Queued for 3-day SLA retry.',
      errors: [
        'NET503: Upstream BIR EIS gateway unavailable; retained in retry queue.',
      ],
      gatewayTier: config.mode,
      processedAt: nowIso,
      jwsThumbprint: envelope.sha256Digest.slice(0, 16),
    };
  }

  if (config.mode !== 'MOCK_BIR_SIMULATOR') {
    const targetUrl =
      config.mode === 'BIR_CERT_SANDBOX'
        ? config.certEndpoint
        : config.prodEndpoint;
    const proxyUrl = Deno.env.get('BIR_EGRESS_PROXY_URL')?.trim() ?? '';
    const fetchUrl = proxyUrl.length > 0 ? proxyUrl : targetUrl;

    try {
      const response = await fetch(fetchUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-BIR-TIN': taxpayer.tin,
          'X-BIR-CERT-ID': taxpayer.eisCertId,
          'X-BIR-PTT': taxpayer.pttNumber,
          ...(proxyUrl.length > 0 ? { 'X-BIR-Target-URL': targetUrl } : {}),
        },
        body: JSON.stringify(envelope),
        signal: AbortSignal.timeout(5000),
      });

      if (response.status < 200 || response.status >= 300) {
        return {
          ackCode: 'NET503',
          accepted: false,
          birAckId: null,
          message: `External BIR endpoint (${targetUrl}) returned HTTP ${response.status}. Queued for retry.`,
          errors: [`HTTP_${response.status} from ${targetUrl}`],
          gatewayTier: config.mode,
          processedAt: nowIso,
          jwsThumbprint: envelope.sha256Digest.slice(0, 16),
        };
      }

      const json = (await response.json()) as Record<string, unknown>;
      return {
        ackCode: String(json['ackCode'] ?? 'ACK-200'),
        accepted: json['accepted'] !== false,
        birAckId:
          json['birAckId'] != null
            ? String(json['birAckId'])
            : randomAckId(nowIso),
        message: String(json['message'] ?? `Accepted by ${targetUrl}`),
        errors: [],
        gatewayTier: config.mode,
        processedAt: nowIso,
        jwsThumbprint: envelope.sha256Digest.slice(0, 16),
      };
    } catch (err) {
      return {
        ackCode: 'NET503',
        accepted: false,
        birAckId: null,
        message: `Cannot reach ${targetUrl} without whitelisted PTT VPN/IP (${err}). Queued for 3-day retry.`,
        errors: [err instanceof Error ? err.message : String(err)],
        gatewayTier: config.mode,
        processedAt: nowIso,
        jwsThumbprint: envelope.sha256Digest.slice(0, 16),
      };
    }
  }

  // Tier 1: Built-in Spec-Faithful BIR EIS Simulator
  let jwsToken: string;
  try {
    jwsToken = await decryptAes256Envelope(envelope, taxpayer.aesKeyHex);
  } catch (err) {
    return {
      ackCode: 'SEC001',
      accepted: false,
      birAckId: null,
      message: 'SEC001: AES-256 decryption failed at BIR Simulator.',
      errors: [err instanceof Error ? err.message : String(err)],
      gatewayTier: 'MOCK_BIR_SIMULATOR',
      processedAt: nowIso,
      jwsThumbprint: envelope.sha256Digest.slice(0, 16),
    };
  }

  const verified = await verifyBirPayloadJws(jwsToken, taxpayer.publicKeyJson);
  if (!verified.valid || !verified.payload) {
    return {
      ackCode: 'SEC001',
      accepted: false,
      birAckId: null,
      message: 'SEC001: JWS (RS256) signature verification failed.',
      errors: [verified.error ?? 'Signature mismatch'],
      gatewayTier: 'MOCK_BIR_SIMULATOR',
      processedAt: nowIso,
      jwsThumbprint: verified.thumbprint,
    };
  }

  const payload = verified.payload as unknown as BirEisPayloadV201;

  if (allowDuplicateCheck) {
    const { data: existing } = await serviceClient
      .from('invoices')
      .select('id')
      .eq('eis_unique_id', payload.EisUniqueId)
      .eq('status', 'TRANSMITTED')
      .maybeSingle();

    if (existing) {
      return {
        ackCode: 'DUP001',
        accepted: false,
        birAckId: null,
        message: `DUP001: EisUniqueId ${payload.EisUniqueId} was already transmitted to BIR EIS.`,
        errors: [`DUP001: Duplicate EisUniqueId (${payload.EisUniqueId})`],
        gatewayTier: 'MOCK_BIR_SIMULATOR',
        processedAt: nowIso,
        jwsThumbprint: verified.thumbprint,
      };
    }
  }

  const schemaErrors = validateBirSchemaV201(payload);
  if (schemaErrors.length > 0) {
    return {
      ackCode: 'SYN004',
      accepted: false,
      birAckId: null,
      message: `SYN004: BIR EIS Schema v2.01 structural validation failed (${schemaErrors.length} error(s)).`,
      errors: schemaErrors,
      gatewayTier: 'MOCK_BIR_SIMULATOR',
      processedAt: nowIso,
      jwsThumbprint: verified.thumbprint,
    };
  }

  const mathErrors = validateBirArithmetic(payload);
  if (mathErrors.length > 0) {
    return {
      ackCode: 'VAL001',
      accepted: false,
      birAckId: null,
      message: `VAL001: BIR EIS arithmetic check failed (${mathErrors.length} error(s)).`,
      errors: mathErrors,
      gatewayTier: 'MOCK_BIR_SIMULATOR',
      processedAt: nowIso,
      jwsThumbprint: verified.thumbprint,
    };
  }

  return {
    ackCode: 'ACK-200',
    accepted: true,
    birAckId: randomAckId(payload.IssueDtm),
    message: `ACK-200: Accepted by BIR EIS Simulator (${payload.SystemType} v2.01). JWS & AES-256 verified.`,
    errors: [],
    gatewayTier: 'MOCK_BIR_SIMULATOR',
    processedAt: nowIso,
    jwsThumbprint: verified.thumbprint,
  };
}
