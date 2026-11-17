import 'dart:convert';
import 'package:serverpod/serverpod.dart';
import '../bir/bir_eis_schema.dart';
import '../bir/eis_runtime.dart';
import '../bir/erp_connectors_service.dart';

/// Serverpod RPC Endpoint exposing Philippine BIR EIS v2.01 & CAS operations
/// via generated `client.eis.*` methods.
class EisEndpoint extends Endpoint {
  Future<String> getDashboardSummary(
    Session session, {
    String? taxpayerId,
  }) async {
    final engine = await EisRuntime.getEngine();
    return jsonEncode(engine.getDashboardSummary(taxpayerId));
  }

  Future<String> updateGatewayConfig(
    Session session, {
    String? mode,
    bool? simulateOutage,
  }) async {
    final engine = await EisRuntime.getEngine();
    final updated = engine.setGatewayConfig(
      mode: mode,
      simulateOutage: simulateOutage,
    );
    return jsonEncode(updated.toJson());
  }

  Future<String> getTaxpayers(Session session) async {
    final engine = await EisRuntime.getEngine();
    final safe = engine
        .getTaxpayers()
        .map((tp) => tp.toJson(includePrivate: false))
        .toList();
    return jsonEncode(safe);
  }

  Future<String> registerTaxpayer(Session session, String bodyJson) async {
    final engine = await EisRuntime.getEngine();
    final map = jsonDecode(bodyJson) as Map<String, dynamic>;
    final created = engine.registerTaxpayer(
      workspaceId: map['workspaceId']?.toString() ?? 'WS-PH-DEFAULT',
      tin: map['tin']?.toString() ?? '',
      taxType: map['taxType']?.toString() ?? 'VAT',
      registeredName: map['registeredName']?.toString() ?? '',
      businessName: map['businessName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      eisCertId: map['eisCertId']?.toString(),
      pttNumber: map['pttNumber']?.toString(),
      headOfficeAddress: BirAddress.fromJson(
        (map['headOfficeAddress'] as Map<String, dynamic>?) ?? const {},
      ),
    );
    return jsonEncode(created.toJson(includePrivate: false));
  }

  Future<String> rotateTaxpayerKeys(
    Session session,
    String taxpayerId,
  ) async {
    final engine = await EisRuntime.getEngine();
    final tp = engine.rotateTaxpayerKeys(taxpayerId);
    return jsonEncode({
      'id': tp.id,
      'keyId': tp.keyId,
      'publicKeyPem': tp.publicKeyJson,
    });
  }

  Future<String> getInvoices(
    Session session, {
    String? taxpayerId,
  }) async {
    final engine = await EisRuntime.getEngine();
    final list = engine.getInvoices(taxpayerId).map((i) => i.toJson()).toList();
    return jsonEncode(list);
  }

  Future<String> createInvoice(Session session, String payloadJson) async {
    final engine = await EisRuntime.getEngine();
    final map = jsonDecode(payloadJson) as Map<String, dynamic>;
    final forceInvalid = map['forceInvalidPayload'] == true;
    final record = await engine.ingestAndTransmitInvoice(
      CanonicalIngestInput.fromJson(map),
      forceInvalidPayload: forceInvalid,
    );
    return jsonEncode(record.toJson());
  }

  Future<String> processRetryQueue(Session session) async {
    final engine = await EisRuntime.getEngine();
    return jsonEncode(await engine.processRetryQueue());
  }

  Future<String> issueCreditMemo(
    Session session,
    String invoiceId, {
    String reason = 'Sales Return / Price Adjustment',
  }) async {
    final engine = await EisRuntime.getEngine();
    final cm = await engine.issueCreditMemo(invoiceId, reason: reason);
    return jsonEncode(cm.toJson());
  }

  Future<String> syncConnector(
    Session session,
    String connector,
    String payloadJson, {
    String? taxpayerId,
  }) async {
    final engine = await EisRuntime.getEngine();
    final map = jsonDecode(payloadJson) as Map<String, dynamic>;
    final rec = switch (connector) {
      'xero' => await engine.ingestFromXero(map, taxpayerId: taxpayerId),
      'quickbooks' =>
        await engine.ingestFromQuickBooks(map, taxpayerId: taxpayerId),
      'odoo' => await engine.ingestFromOdoo(map, taxpayerId: taxpayerId),
      _ => throw ArgumentError('Unsupported connector: $connector'),
    };
    return jsonEncode(rec.toJson());
  }

  Future<int> importCsvBatch(
    Session session,
    String csvText, {
    String? taxpayerId,
  }) async {
    final engine = await EisRuntime.getEngine();
    final list =
        await engine.ingestFromCsvBatch(csvText, taxpayerId: taxpayerId);
    return list.length;
  }

  Future<String> getCasBooks(
    Session session, {
    String? taxpayerId,
    String bookType = 'ALL',
  }) async {
    final engine = await EisRuntime.getEngine();
    return jsonEncode(
      engine.getCasBooks(taxpayerId: taxpayerId, bookType: bookType),
    );
  }

  Future<String> generateSlsp(
    Session session, {
    String? taxpayerId,
    String kind = 'SALES',
    String period = '202611',
  }) async {
    final engine = await EisRuntime.getEngine();
    return jsonEncode(engine.generateSlsp(taxpayerId, kind, period: period));
  }

  Future<String> generateWithholdingDat(
    Session session, {
    String? taxpayerId,
    String kind = 'SAWT',
    String period = '202612',
  }) async {
    final engine = await EisRuntime.getEngine();
    return jsonEncode(
      engine.generateWithholdingDat(taxpayerId, kind, period: period),
    );
  }

  Future<String> generateForm2307(Session session, String invoiceId) async {
    final engine = await EisRuntime.getEngine();
    return jsonEncode(engine.generateForm2307ForInvoice(invoiceId));
  }

  Future<String> getAuditTrail(Session session) async {
    final engine = await EisRuntime.getEngine();
    return jsonEncode({
      'verification': engine.auditTrail.verifyIntegrity(),
      'entries':
          engine.auditTrail.getEntries().reversed.map((e) => e.toJson()).toList(),
    });
  }
}
