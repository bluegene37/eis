import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ies_models.dart';

class IesApiClient {
  final String baseUrl;
  final http.Client _client;

  IesApiClient({
    this.baseUrl = 'http://localhost:4000/api',
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<dynamic> _get(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode >= 400) {
      throw Exception('GET $path failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
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
    final q = taxpayerId != null ? '?taxpayerId=$taxpayerId' : '';
    final json = await _get('/dashboard/summary$q') as Map<String, dynamic>;
    return DashboardSummaryModel.fromJson(json);
  }

  Future<List<TaxpayerProfileModel>> fetchTaxpayers() async {
    final list = await _get('/taxpayers') as List<dynamic>;
    return list
        .map((e) => TaxpayerProfileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<StoredInvoiceModel>> fetchInvoices({String? taxpayerId}) async {
    final q = taxpayerId != null ? '?taxpayerId=$taxpayerId' : '';
    final list = await _get('/invoices$q') as List<dynamic>;
    return list
        .map((e) => StoredInvoiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateGatewayConfig({String? mode, bool? simulateOutage}) async {
    await _post('/gateway/config', {
      'mode': ?mode,
      'simulateOutage': ?simulateOutage,
    });
  }

  Future<Map<String, dynamic>> processRetryQueue() async {
    return await _post('/invoices/retry-queue', {}) as Map<String, dynamic>;
  }

  Future<StoredInvoiceModel> createInvoice(Map<String, dynamic> payload) async {
    final json = await _post('/invoices', payload) as Map<String, dynamic>;
    return StoredInvoiceModel.fromJson(json);
  }

  Future<StoredInvoiceModel> issueCreditMemo(String invoiceId, String reason) async {
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
    final q = taxpayerId != null ? '?taxpayerId=$taxpayerId' : '';
    final json =
        await _post('/connectors/$connector$q', payload) as Map<String, dynamic>;
    return StoredInvoiceModel.fromJson(json);
  }

  Future<int> importCsvBatch(String csv, {String? taxpayerId}) async {
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
    return await _get('/statutory/form2307/$invoiceId') as Map<String, dynamic>;
  }

  Future<AuditTrailResponseModel> fetchAuditTrail() async {
    final json = await _get('/audit-trail') as Map<String, dynamic>;
    return AuditTrailResponseModel.fromJson(json);
  }

  Future<void> registerTaxpayer(Map<String, dynamic> body) async {
    await _post('/taxpayers', body);
  }

  Future<void> rotateTaxpayerKeys(String taxpayerId) async {
    await _post('/taxpayers/$taxpayerId/rotate-keys', {});
  }
}
