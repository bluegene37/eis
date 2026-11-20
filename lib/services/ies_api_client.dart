// Gene - Nov, 20, 2026: Dual-mode client supporting embedded local pure-Dart BIR EIS/CAS engine (default standalone) and optional Remote REST API / MockClient HTTP transport.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/bir/bir_eis_schema.dart';
import '../core/bir/eis_engine_service.dart';
import '../core/bir/eis_local_runtime.dart';
import '../core/bir/erp_connectors_service.dart';
import '../models/ies_models.dart';

/// Unified client supporting the embedded local pure-Dart BIR EIS/CAS engine
/// by default (standalone mobile/desktop/web) as well as REST / MockClient HTTP transport.
class IesApiClient {
  final String baseUrl;
  final bool useRemoteRest;
  // final Future<EisEngineService> Function()? _engineProvider;
  // Gene - Nov, 20, 2026: Use public field & initializing formal `this.engineProvider` to satisfy Dart 3.14+ prefer_initializing_formals lint.
  final Future<EisEngineService> Function()? engineProvider;
  final http.Client? _httpClient;

  // IesApiClient({
  //   this.baseUrl = 'http://localhost:4000',
  //   this.useRemoteRest = false,
  //   Future<EisEngineService> Function()? engineProvider,
  //   http.Client? client,
  // })  : _engineProvider = engineProvider,
  //       _httpClient = client;
  IesApiClient({
    this.baseUrl = 'http://localhost:4000',
    this.useRemoteRest = false,
    this.engineProvider,
    http.Client? client,
  }) : _httpClient = client;

  bool get isEmbedded => !useRemoteRest && _httpClient == null;

  String get connectionLabel => isEmbedded ? 'Local Embedded Engine' : baseUrl;

  Future<EisEngineService> _getEngine() =>
      (engineProvider ?? EisLocalRuntime.getEngine)();

  http.Client get _http => _httpClient ?? http.Client();

  Future<dynamic> _get(String path) async {
    final restBase = baseUrl.endsWith('/api')
        ? baseUrl
        : '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api';
    final response = await _http.get(Uri.parse('$restBase$path'));
    if (response.statusCode >= 400) {
      throw Exception(
        'GET $path failed (${response.statusCode}): ${response.body}',
      );
    }
    return jsonDecode(response.body);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final restBase = baseUrl.endsWith('/api')
        ? baseUrl
        : '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api';
    final response = await _http.post(
      Uri.parse('$restBase$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 400 && response.statusCode != 422) {
      throw Exception(
        (decoded is Map && decoded['error'] != null)
            ? decoded['error'].toString()
            : 'POST $path failed (${response.statusCode})',
      );
    }
    return decoded;
  }

  Future<DashboardSummaryModel> fetchDashboard({String? taxpayerId}) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      return DashboardSummaryModel.fromJson(
        engine.getDashboardSummary(taxpayerId),
      );
    }
    final q = taxpayerId != null ? '?taxpayerId=$taxpayerId' : '';
    final json = await _get('/dashboard/summary$q') as Map<String, dynamic>;
    return DashboardSummaryModel.fromJson(json);
  }

  Future<List<TaxpayerProfileModel>> fetchTaxpayers() async {
    if (isEmbedded) {
      final engine = await _getEngine();
      return engine
          .getTaxpayers()
          .map(
            (tp) => TaxpayerProfileModel.fromJson(
              tp.toJson(includePrivate: false),
            ),
          )
          .toList();
    }
    final list = await _get('/taxpayers') as List<dynamic>;
    return list
        .map((e) => TaxpayerProfileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<StoredInvoiceModel>> fetchInvoices({String? taxpayerId}) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      return engine
          .getInvoices(taxpayerId)
          .map((i) => StoredInvoiceModel.fromJson(i.toJson()))
          .toList();
    }
    final q = taxpayerId != null ? '?taxpayerId=$taxpayerId' : '';
    final list = await _get('/invoices$q') as List<dynamic>;
    return list
        .map((e) => StoredInvoiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateGatewayConfig({String? mode, bool? simulateOutage}) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      engine.setGatewayConfig(mode: mode, simulateOutage: simulateOutage);
      return;
    }
    await _post('/gateway/config', {
      'mode': ?mode,
      'simulateOutage': ?simulateOutage,
    });
  }

  Future<Map<String, dynamic>> processRetryQueue() async {
    if (isEmbedded) {
      final engine = await _getEngine();
      return await engine.processRetryQueue();
    }
    return await _post('/invoices/retry-queue', {}) as Map<String, dynamic>;
  }

  Future<StoredInvoiceModel> createInvoice(Map<String, dynamic> payload) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      final forceInvalid = payload['forceInvalidPayload'] == true;
      final record = await engine.ingestAndTransmitInvoice(
        CanonicalIngestInput.fromJson(payload),
        forceInvalidPayload: forceInvalid,
      );
      return StoredInvoiceModel.fromJson(record.toJson());
    }
    final json = await _post('/invoices', payload) as Map<String, dynamic>;
    return StoredInvoiceModel.fromJson(json);
  }

  Future<StoredInvoiceModel> issueCreditMemo(
    String invoiceId,
    String reason,
  ) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      final cm = await engine.issueCreditMemo(invoiceId, reason: reason);
      return StoredInvoiceModel.fromJson(cm.toJson());
    }
    final json =
        await _post('/invoices/$invoiceId/credit-memo', {'reason': reason})
            as Map<String, dynamic>;
    return StoredInvoiceModel.fromJson(json);
  }

  Future<StoredInvoiceModel> syncConnector(
    String connector,
    Map<String, dynamic> payload, {
    String? taxpayerId,
  }) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      final rec = switch (connector) {
        'xero' => await engine.ingestFromXero(payload, taxpayerId: taxpayerId),
        'quickbooks' =>
          await engine.ingestFromQuickBooks(payload, taxpayerId: taxpayerId),
        'odoo' => await engine.ingestFromOdoo(payload, taxpayerId: taxpayerId),
        _ => throw ArgumentError('Unsupported connector: $connector'),
      };
      return StoredInvoiceModel.fromJson(rec.toJson());
    }
    final q = taxpayerId != null ? '?taxpayerId=$taxpayerId' : '';
    final json =
        await _post('/connectors/$connector$q', payload) as Map<String, dynamic>;
    return StoredInvoiceModel.fromJson(json);
  }

  Future<int> importCsvBatch(String csv, {String? taxpayerId}) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      final list =
          await engine.ingestFromCsvBatch(csv, taxpayerId: taxpayerId);
      return list.length;
    }
    final json = await _post('/connectors/csv', {
      'csv': csv,
      'taxpayerId': ?taxpayerId,
    }) as Map<String, dynamic>;
    return (json['importedCount'] as num?)?.toInt() ?? 0;
  }

  Future<CasBooksDataModel> fetchCasBooks({
    String? taxpayerId,
    String bookType = 'ALL',
  }) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      return CasBooksDataModel.fromJson(
        engine.getCasBooks(taxpayerId: taxpayerId, bookType: bookType),
      );
    }
    final params = <String>[
      'bookType=$bookType',
      if (taxpayerId != null) 'taxpayerId=$taxpayerId',
    ].join('&');
    final json = await _get('/cas/books?$params') as Map<String, dynamic>;
    return CasBooksDataModel.fromJson(json);
  }

  Future<StatutoryReportModel> fetchSlsp({
    String? taxpayerId,
    required String kind,
    String period = '202611',
  }) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      return StatutoryReportModel.fromJson(
        engine.generateSlsp(taxpayerId, kind, period: period),
      );
    }
    final params = <String>[
      'kind=$kind',
      'period=$period',
      if (taxpayerId != null) 'taxpayerId=$taxpayerId',
    ].join('&');
    final json = await _get('/statutory/slsp?$params') as Map<String, dynamic>;
    return StatutoryReportModel.fromJson(json);
  }

  Future<StatutoryReportModel> fetchWithholdingDat({
    String? taxpayerId,
    required String kind,
    String period = '202612',
  }) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      return StatutoryReportModel.fromJson(
        engine.generateWithholdingDat(taxpayerId, kind, period: period),
      );
    }
    final params = <String>[
      'kind=$kind',
      'period=$period',
      if (taxpayerId != null) 'taxpayerId=$taxpayerId',
    ].join('&');
    final json =
        await _get('/statutory/withholding?$params') as Map<String, dynamic>;
    return StatutoryReportModel.fromJson(json);
  }

  Future<Map<String, dynamic>> fetchForm2307(String invoiceId) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      return engine.generateForm2307ForInvoice(invoiceId);
    }
    return await _get('/statutory/form2307/$invoiceId') as Map<String, dynamic>;
  }

  Future<AuditTrailResponseModel> fetchAuditTrail() async {
    if (isEmbedded) {
      final engine = await _getEngine();
      return AuditTrailResponseModel.fromJson({
        'verification': engine.auditTrail.verifyIntegrity(),
        'entries': engine.auditTrail
            .getEntries()
            .reversed
            .map((e) => e.toJson())
            .toList(),
      });
    }
    final json = await _get('/audit-trail') as Map<String, dynamic>;
    return AuditTrailResponseModel.fromJson(json);
  }

  Future<void> registerTaxpayer(Map<String, dynamic> body) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      engine.registerTaxpayer(
        workspaceId: body['workspaceId']?.toString() ?? 'WS-PH-DEFAULT',
        tin: body['tin']?.toString() ?? '',
        taxType: body['taxType']?.toString() ?? 'VAT',
        registeredName: body['registeredName']?.toString() ?? '',
        businessName: body['businessName']?.toString() ?? '',
        email: body['email']?.toString() ?? '',
        eisCertId: body['eisCertId']?.toString(),
        pttNumber: body['pttNumber']?.toString(),
        headOfficeAddress: BirAddress.fromJson(
          (body['headOfficeAddress'] as Map<String, dynamic>?) ?? const {},
        ),
      );
      return;
    }
    await _post('/taxpayers', body);
  }

  Future<void> rotateTaxpayerKeys(String taxpayerId) async {
    if (isEmbedded) {
      final engine = await _getEngine();
      engine.rotateTaxpayerKeys(taxpayerId);
      return;
    }
    await _post('/taxpayers/$taxpayerId/rotate-keys', {});
  }
}
