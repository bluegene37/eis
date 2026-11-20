import 'dart:convert';
import 'package:eis_client/eis_client.dart' as sp;
import 'package:http/http.dart' as http;
import '../models/ies_models.dart';

/// Unified client supporting native Serverpod RPC (`eis_client`) in production
/// as well as REST / MockClient HTTP transport for tests and webhooks.
class IesApiClient {
  final String baseUrl;
  // final sp.Client? _serverpodClient;
  // Gene - Nov, 20, 2026: Use initializing formal `this.serverpodClient` to satisfy Dart 3.12+ prefer_initializing_formals lint.
  final sp.Client? serverpodClient;
  final http.Client? _httpClient;

  // IesApiClient({
  //   this.baseUrl = 'http://localhost:8080/',
  //   sp.Client? serverpodClient,
  //   http.Client? client,
  // })  : _serverpodClient = serverpodClient,
  //       _httpClient = client;
  IesApiClient({
    this.baseUrl = 'http://localhost:8080/',
    this.serverpodClient,
    http.Client? client,
  }) : _httpClient = client;

  sp.Client? get _serverpodClient => serverpodClient;

  http.Client get _http => _httpClient ?? http.Client();

  bool get _useServerpod => _serverpodClient != null && _httpClient == null;

  Future<dynamic> _get(String path) async {
    final restBase = baseUrl.endsWith('/api')
        ? baseUrl
        : '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api';
    final response = await _http.get(Uri.parse('$restBase$path'));
    if (response.statusCode >= 400) {
      throw Exception('GET $path failed (${response.statusCode}): ${response.body}');
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
    if (_useServerpod) {
      final raw =
          await _serverpodClient!.eis.getDashboardSummary(taxpayerId: taxpayerId);
      return DashboardSummaryModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
    final q = taxpayerId != null ? '?taxpayerId=$taxpayerId' : '';
    final json = await _get('/dashboard/summary$q') as Map<String, dynamic>;
    return DashboardSummaryModel.fromJson(json);
  }

  Future<List<TaxpayerProfileModel>> fetchTaxpayers() async {
    if (_useServerpod) {
      final raw = await _serverpodClient!.eis.getTaxpayers();
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TaxpayerProfileModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final list = await _get('/taxpayers') as List<dynamic>;
    return list
        .map((e) => TaxpayerProfileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<StoredInvoiceModel>> fetchInvoices({String? taxpayerId}) async {
    if (_useServerpod) {
      final raw =
          await _serverpodClient!.eis.getInvoices(taxpayerId: taxpayerId);
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => StoredInvoiceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final q = taxpayerId != null ? '?taxpayerId=$taxpayerId' : '';
    final list = await _get('/invoices$q') as List<dynamic>;
    return list
        .map((e) => StoredInvoiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateGatewayConfig({String? mode, bool? simulateOutage}) async {
    if (_useServerpod) {
      await _serverpodClient!.eis.updateGatewayConfig(
        mode: mode,
        simulateOutage: simulateOutage,
      );
      return;
    }
    await _post('/gateway/config', {
      'mode': ?mode,
      'simulateOutage': ?simulateOutage,
    });
  }

  Future<Map<String, dynamic>> processRetryQueue() async {
    if (_useServerpod) {
      final raw = await _serverpodClient!.eis.processRetryQueue();
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return await _post('/invoices/retry-queue', {}) as Map<String, dynamic>;
  }

  Future<StoredInvoiceModel> createInvoice(Map<String, dynamic> payload) async {
    if (_useServerpod) {
      final raw =
          await _serverpodClient!.eis.createInvoice(jsonEncode(payload));
      return StoredInvoiceModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
    final json = await _post('/invoices', payload) as Map<String, dynamic>;
    return StoredInvoiceModel.fromJson(json);
  }

  Future<StoredInvoiceModel> issueCreditMemo(
    String invoiceId,
    String reason,
  ) async {
    if (_useServerpod) {
      final raw = await _serverpodClient!.eis.issueCreditMemo(
        invoiceId,
        reason: reason,
      );
      return StoredInvoiceModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
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
    if (_useServerpod) {
      final raw = await _serverpodClient!.eis.syncConnector(
        connector,
        jsonEncode(payload),
        taxpayerId: taxpayerId,
      );
      return StoredInvoiceModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
    final q = taxpayerId != null ? '?taxpayerId=$taxpayerId' : '';
    final json =
        await _post('/connectors/$connector$q', payload) as Map<String, dynamic>;
    return StoredInvoiceModel.fromJson(json);
  }

  Future<int> importCsvBatch(String csv, {String? taxpayerId}) async {
    if (_useServerpod) {
      return _serverpodClient!.eis.importCsvBatch(
        csv,
        taxpayerId: taxpayerId,
      );
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
    if (_useServerpod) {
      final raw = await _serverpodClient!.eis.getCasBooks(
        taxpayerId: taxpayerId,
        bookType: bookType,
      );
      return CasBooksDataModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
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
    if (_useServerpod) {
      final raw = await _serverpodClient!.eis.generateSlsp(
        taxpayerId: taxpayerId,
        kind: kind,
        period: period,
      );
      return StatutoryReportModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
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
    if (_useServerpod) {
      final raw = await _serverpodClient!.eis.generateWithholdingDat(
        taxpayerId: taxpayerId,
        kind: kind,
        period: period,
      );
      return StatutoryReportModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
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
    if (_useServerpod) {
      final raw = await _serverpodClient!.eis.generateForm2307(invoiceId);
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return await _get('/statutory/form2307/$invoiceId') as Map<String, dynamic>;
  }

  Future<AuditTrailResponseModel> fetchAuditTrail() async {
    if (_useServerpod) {
      final raw = await _serverpodClient!.eis.getAuditTrail();
      return AuditTrailResponseModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
    final json = await _get('/audit-trail') as Map<String, dynamic>;
    return AuditTrailResponseModel.fromJson(json);
  }

  Future<void> registerTaxpayer(Map<String, dynamic> body) async {
    if (_useServerpod) {
      await _serverpodClient!.eis.registerTaxpayer(jsonEncode(body));
      return;
    }
    await _post('/taxpayers', body);
  }

  Future<void> rotateTaxpayerKeys(String taxpayerId) async {
    if (_useServerpod) {
      await _serverpodClient!.eis.rotateTaxpayerKeys(taxpayerId);
      return;
    }
    await _post('/taxpayers/$taxpayerId/rotate-keys', {});
  }
}
