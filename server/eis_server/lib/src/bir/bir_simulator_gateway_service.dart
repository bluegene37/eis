import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'bir_eis_schema.dart';
import 'crypto_jws_aes_service.dart';
import 'tax_calculator_service.dart';

class BirGatewayConfig {
  String mode; // MOCK_BIR_SIMULATOR | BIR_CERT_SANDBOX | BIR_PRODUCTION
  bool simulateOutage;
  final String certEndpoint;
  final String prodEndpoint;

  BirGatewayConfig({
    this.mode = 'MOCK_BIR_SIMULATOR',
    this.simulateOutage = false,
    this.certEndpoint = 'https://eis-cert.bir.gov.ph/api/v2.01/invoices',
    this.prodEndpoint = 'https://eis.bir.gov.ph/api/v2.01/invoices',
  });

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'simulateOutage': simulateOutage,
        'certEndpoint': certEndpoint,
        'prodEndpoint': prodEndpoint,
      };
}

/// 3-Tier BIR EIS Gateway & Built-in Spec-Faithful Certification Simulator.
class BirSimulatorGatewayService {
  final Set<String> _seenEisUniqueIds = <String>{};
  final BirGatewayConfig config = BirGatewayConfig();

  void registerKnownEisId(String eisUniqueId) {
    _seenEisUniqueIds.add(eisUniqueId);
  }

  void clearSeenIds() {
    _seenEisUniqueIds.clear();
  }

  Future<BirGatewayReceipt> transmitEnvelope(
    AesGcmEnvelope envelope,
    TaxpayerProfile taxpayer, {
    bool allowDuplicateCheck = true,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (config.simulateOutage) {
      return BirGatewayReceipt(
        ackCode: 'NET503',
        accepted: false,
        birAckId: null,
        message:
            'BIR EIS Gateway unreachable (simulated 503 maintenance window). Queued for 3-day SLA retry.',
        errors: const [
          'NET503: Upstream BIR EIS gateway unavailable; retained in retry queue.',
        ],
        gatewayTier: config.mode,
        processedAt: nowIso,
        jwsThumbprint: envelope.sha256Digest.substring(0, 16),
      );
    }

    if (config.mode != 'MOCK_BIR_SIMULATOR') {
      final targetUrl = config.mode == 'BIR_CERT_SANDBOX'
          ? config.certEndpoint
          : config.prodEndpoint;
      try {
        final response = await http
            .post(
              Uri.parse(targetUrl),
              headers: {
                'Content-Type': 'application/json',
                'X-BIR-TIN': taxpayer.tin,
                'X-BIR-CERT-ID': taxpayer.eisCertId,
                'X-BIR-PTT': taxpayer.pttNumber,
              },
              body: jsonEncode(envelope.toJson()),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          return BirGatewayReceipt(
            ackCode: 'NET503',
            accepted: false,
            birAckId: null,
            message:
                'External BIR endpoint ($targetUrl) returned HTTP ${response.statusCode}. Queued for retry.',
            errors: ['HTTP_${response.statusCode} from $targetUrl'],
            gatewayTier: config.mode,
            processedAt: nowIso,
            jwsThumbprint: envelope.sha256Digest.substring(0, 16),
          );
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return BirGatewayReceipt(
          ackCode: json['ackCode']?.toString() ?? 'ACK-200',
          accepted: json['accepted'] != false,
          birAckId: json['birAckId']?.toString() ?? _randomAckId(nowIso),
          message: json['message']?.toString() ?? 'Accepted by $targetUrl',
          errors: const [],
          gatewayTier: config.mode,
          processedAt: nowIso,
          jwsThumbprint: envelope.sha256Digest.substring(0, 16),
        );
      } catch (err) {
        return BirGatewayReceipt(
          ackCode: 'NET503',
          accepted: false,
          birAckId: null,
          message:
              'Cannot reach $targetUrl without whitelisted PTT VPN/IP ($err). Queued for 3-day retry.',
          errors: [err.toString()],
          gatewayTier: config.mode,
          processedAt: nowIso,
          jwsThumbprint: envelope.sha256Digest.substring(0, 16),
        );
      }
    }

    // Tier 1: Built-in Spec-Faithful BIR EIS Simulator
    late final String jwsToken;
    try {
      jwsToken = decryptAes256Envelope(envelope, taxpayer.aesKeyHex);
    } catch (err) {
      return BirGatewayReceipt(
        ackCode: 'SEC001',
        accepted: false,
        birAckId: null,
        message: 'SEC001: AES-256 decryption failed at BIR Simulator.',
        errors: [err.toString()],
        gatewayTier: 'MOCK_BIR_SIMULATOR',
        processedAt: nowIso,
        jwsThumbprint: envelope.sha256Digest.substring(0, 16),
      );
    }

    final verified = verifyBirPayloadJws(jwsToken, taxpayer.publicKeyJson);
    if (!verified.valid || verified.payload == null) {
      return BirGatewayReceipt(
        ackCode: 'SEC001',
        accepted: false,
        birAckId: null,
        message: 'SEC001: JWS (RS256) signature verification failed.',
        errors: [verified.error ?? 'Signature mismatch'],
        gatewayTier: 'MOCK_BIR_SIMULATOR',
        processedAt: nowIso,
        jwsThumbprint: verified.thumbprint,
      );
    }

    final payload = BirEisPayloadV201.fromJson(verified.payload!);

    if (allowDuplicateCheck &&
        _seenEisUniqueIds.contains(payload.eisUniqueId)) {
      return BirGatewayReceipt(
        ackCode: 'DUP001',
        accepted: false,
        birAckId: null,
        message:
            'DUP001: EisUniqueId ${payload.eisUniqueId} was already transmitted to BIR EIS.',
        errors: ['DUP001: Duplicate EisUniqueId (${payload.eisUniqueId})'],
        gatewayTier: 'MOCK_BIR_SIMULATOR',
        processedAt: nowIso,
        jwsThumbprint: verified.thumbprint,
      );
    }

    final schemaErrors = validateBirSchemaV201(payload);
    if (schemaErrors.isNotEmpty) {
      return BirGatewayReceipt(
        ackCode: 'SYN004',
        accepted: false,
        birAckId: null,
        message:
            'SYN004: BIR EIS Schema v2.01 structural validation failed (${schemaErrors.length} error(s)).',
        errors: schemaErrors,
        gatewayTier: 'MOCK_BIR_SIMULATOR',
        processedAt: nowIso,
        jwsThumbprint: verified.thumbprint,
      );
    }

    final mathErrors = validateBirArithmetic(payload);
    if (mathErrors.isNotEmpty) {
      return BirGatewayReceipt(
        ackCode: 'VAL001',
        accepted: false,
        birAckId: null,
        message:
            'VAL001: BIR EIS arithmetic check failed (${mathErrors.length} error(s)).',
        errors: mathErrors,
        gatewayTier: 'MOCK_BIR_SIMULATOR',
        processedAt: nowIso,
        jwsThumbprint: verified.thumbprint,
      );
    }

    _seenEisUniqueIds.add(payload.eisUniqueId);
    final birAckId = _randomAckId(payload.issueDtm);

    return BirGatewayReceipt(
      ackCode: 'ACK-200',
      accepted: true,
      birAckId: birAckId,
      message:
          'ACK-200: Accepted by BIR EIS Simulator (${payload.systemType} v2.01). JWS & AES-256 verified.',
      errors: const [],
      gatewayTier: 'MOCK_BIR_SIMULATOR',
      processedAt: nowIso,
      jwsThumbprint: verified.thumbprint,
    );
  }

  String _randomAckId(String dateRef) {
    final rng = Random.secure();
    final suffix = List.generate(
      4,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join().toUpperCase();
    final datePart = dateRef.substring(0, 10).replaceAll('-', '');
    return 'BIR-ACK-$datePart-$suffix';
  }
}
