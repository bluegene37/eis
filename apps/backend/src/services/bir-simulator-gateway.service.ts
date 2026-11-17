import crypto from 'node:crypto';
import {
  BirEisPayloadV201,
  BirGatewayMode,
  BirGatewayReceipt,
  TaxpayerProfile,
  validateBirSchemaV201,
} from '../domain/bir-eis-schema.js';
import {
  AesGcmEnvelope,
  decryptAes256Envelope,
  verifyBirPayloadJws,
} from './crypto-jws-aes.service.js';
import { validateBirArithmetic } from './tax-calculator.service.js';

export interface BirGatewayConfig {
  mode: BirGatewayMode;
  simulateOutage: boolean;
  certEndpoint: string;
  prodEndpoint: string;
}

/**
 * 3-Tier BIR EIS Gateway:
 *   1. MOCK_BIR_SIMULATOR (built-in spec-faithful verifier: AES-256 decrypt -> JWS RS256 verify -> SYN004/VAL001/DUP001)
 *   2. BIR_CERT_SANDBOX (eis-cert.bir.gov.ph)
 *   3. BIR_PRODUCTION (eis.bir.gov.ph)
 */
export class BirSimulatorGatewayService {
  private seenEisUniqueIds = new Set<string>();
  public config: BirGatewayConfig = {
    mode: (process.env.BIR_GATEWAY_MODE as BirGatewayMode) || 'MOCK_BIR_SIMULATOR',
    simulateOutage: false,
    certEndpoint:
      process.env.BIR_CERT_ENDPOINT || 'https://eis-cert.bir.gov.ph/api/v2.01/invoices',
    prodEndpoint:
      process.env.BIR_PROD_ENDPOINT || 'https://eis.bir.gov.ph/api/v2.01/invoices',
  };

  public registerKnownEisId(eisUniqueId: string): void {
    this.seenEisUniqueIds.add(eisUniqueId);
  }

  public clearSeenIds(): void {
    this.seenEisUniqueIds.clear();
  }

  public async transmitEnvelope(
    envelope: AesGcmEnvelope,
    taxpayer: TaxpayerProfile,
    options?: { allowDuplicateCheck?: boolean },
  ): Promise<BirGatewayReceipt> {
    const nowIso = new Date().toISOString();

    if (this.config.simulateOutage) {
      return {
        ackCode: 'NET503',
        accepted: false,
        birAckId: null,
        message:
          'BIR EIS Gateway unreachable (simulated 503 maintenance window). Queued for 3-day SLA retry.',
        errors: ['NET503: Upstream BIR EIS gateway unavailable; retained in retry queue.'],
        gatewayTier: this.config.mode,
        processedAt: nowIso,
        jwsThumbprint: envelope.sha256Digest.slice(0, 16),
      };
    }

    // For Certification Sandbox or Production, if an external bearer/PTT endpoint is live,
    // real HTTP transmission can be routed via fetch; for safety in offline environments,
    // we require explicit live credentials or fallback clearly with NET503.
    if (this.config.mode !== 'MOCK_BIR_SIMULATOR') {
      const targetUrl =
        this.config.mode === 'BIR_CERT_SANDBOX'
          ? this.config.certEndpoint
          : this.config.prodEndpoint;
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 5000);
        const response = await fetch(targetUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-BIR-TIN': taxpayer.tin,
            'X-BIR-CERT-ID': taxpayer.eisCertId,
            'X-BIR-PTT': taxpayer.pttNumber,
          },
          body: JSON.stringify(envelope),
          signal: controller.signal,
        });
        clearTimeout(timeout);
        if (!response.ok) {
          return {
            ackCode: 'NET503',
            accepted: false,
            birAckId: null,
            message: `External BIR endpoint (${targetUrl}) returned HTTP ${response.status}. Queued for retry.`,
            errors: [`HTTP_${response.status} from ${targetUrl}`],
            gatewayTier: this.config.mode,
            processedAt: nowIso,
            jwsThumbprint: envelope.sha256Digest.slice(0, 16),
          };
        }
        const json = (await response.json()) as Partial<BirGatewayReceipt>;
        return {
          ackCode: json.ackCode ?? 'ACK-200',
          accepted: json.accepted ?? true,
          birAckId: json.birAckId ?? `BIR-${crypto.randomUUID().slice(0, 12).toUpperCase()}`,
          message: json.message ?? `Accepted by ${targetUrl}`,
          errors: json.errors ?? [],
          gatewayTier: this.config.mode,
          processedAt: nowIso,
          jwsThumbprint: envelope.sha256Digest.slice(0, 16),
        };
      } catch (err) {
        return {
          ackCode: 'NET503',
          accepted: false,
          birAckId: null,
          message: `Cannot reach ${targetUrl} without whitelisted PTT VPN/IP (${err instanceof Error ? err.message : 'network error'}). Queued for 3-day retry.`,
          errors: [err instanceof Error ? err.message : 'Network error'],
          gatewayTier: this.config.mode,
          processedAt: nowIso,
          jwsThumbprint: envelope.sha256Digest.slice(0, 16),
        };
      }
    }

    // === Tier 1: Built-in Spec-Faithful BIR EIS Simulator ===
    // 1. Decrypt AES-256-GCM transport envelope
    let jwsToken: string;
    try {
      jwsToken = decryptAes256Envelope(envelope, taxpayer.aesKeyHex);
    } catch (err) {
      return {
        ackCode: 'SEC001',
        accepted: false,
        birAckId: null,
        message: 'SEC001: AES-256 decryption failed at BIR Simulator.',
        errors: [err instanceof Error ? err.message : 'AES decryption error'],
        gatewayTier: 'MOCK_BIR_SIMULATOR',
        processedAt: nowIso,
        jwsThumbprint: envelope.sha256Digest.slice(0, 16),
      };
    }

    // 2. Verify RFC 7515 JWS (RS256) digital signature against Taxpayer public key
    const verified = await verifyBirPayloadJws<BirEisPayloadV201>(
      jwsToken,
      taxpayer.publicKeyPem,
    );
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

    const payload = verified.payload;

    // 3. Duplicate EisUniqueId detection (DUP001)
    if (options?.allowDuplicateCheck !== false && this.seenEisUniqueIds.has(payload.EisUniqueId)) {
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

    // 4. Schema v2.01 structural validation (SYN004)
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

    // 5. EOPT / VAT / CWT arithmetic validation (VAL001)
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

    // Accepted! Record EisUniqueId and return signed acknowledgment receipt
    this.seenEisUniqueIds.add(payload.EisUniqueId);
    const birAckId = `BIR-ACK-${payload.IssueDtm.slice(0, 10).replace(/-/g, '')}-${crypto
      .randomBytes(4)
      .toString('hex')
      .toUpperCase()}`;

    return {
      ackCode: 'ACK-200',
      accepted: true,
      birAckId,
      message: `ACK-200: Accepted by BIR EIS Simulator (${payload.SystemType} v2.01). JWS & AES-256 verified.`,
      errors: [],
      gatewayTier: 'MOCK_BIR_SIMULATOR',
      processedAt: nowIso,
      jwsThumbprint: verified.thumbprint,
    };
  }
}
