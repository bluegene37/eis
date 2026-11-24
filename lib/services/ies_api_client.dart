// Gene - Nov, 20, 2026: Dual-mode client supporting embedded local pure-Dart BIR EIS/CAS engine (default standalone) and optional Remote REST API / MockClient HTTP transport.
// Gene - Nov, 20, 2026: Extended to 3-mode client supporting Local Embedded Engine, Serverpod RPC (:8080 via eis_client), and Remote REST API (:4000) / MockClient.
// Gene - Nov, 24, 2026: Migrated Serverpod RPC backend mode to Supabase (Auth + PostgREST + Edge Functions) while preserving Local Embedded Engine and Remote REST.

import 'dart:convert';
// import 'package:eis_client/eis_client.dart' as sp;
import 'package:http/http.dart' as http;
import '../core/bir/bir_eis_schema.dart';
import '../core/bir/eis_engine_service.dart';
import '../core/bir/eis_local_runtime.dart';
import '../core/bir/erp_connectors_service.dart';
import '../models/ies_models.dart';
import '../models/workspace_models.dart';
import 'supabase_eis_transport.dart';

// Gene - Nov, 20, 2026: Explicit backend transport selector for Local Embedded, Serverpod RPC, and Remote REST modes.
// enum EisBackendMode { embedded, serverpod, remoteRest }
// Gene - Nov, 24, 2026: Replaced serverpod backend mode with supabase.
enum EisBackendMode { embedded, supabase, remoteRest }

/// Unified client supporting the embedded local pure-Dart BIR EIS/CAS engine
/// by default (standalone mobile/desktop/web), Supabase (Auth + RLS Postgres +
/// Edge Functions), and REST / MockClient HTTP transport.
class IesApiClient {
  final String baseUrl;
  final bool useRemoteRest;
  // final Future<EisEngineService> Function()? _engineProvider;
  // Gene - Nov, 20, 2026: Use public field & initializing formal `this.engineProvider` to satisfy Dart 3.14+ prefer_initializing_formals lint.
  final Future<EisEngineService> Function()? engineProvider;
  // final sp.Client? serverpodClient;
  // Gene - Nov, 24, 2026: Replaced serverpodClient with pluggable Supabase transport and publishable key metadata.
  final EisSupabaseTransport? supabaseTransport;
  final String? supabasePublishableKey;
  final http.Client? _httpClient;
  EisAuthSessionState _sessionState;

  // IesApiClient({
  //   this.baseUrl = 'http://localhost:4000',
  //   this.useRemoteRest = false,
  //   this.engineProvider,
  //   http.Client? client,
  // }) : _httpClient = client;
  // IesApiClient({
  //   this.baseUrl = 'http://localhost:4000',
  //   this.useRemoteRest = false,
  //   this.engineProvider,
  //   this.serverpodClient,
  //   http.Client? client,
  // }) : _httpClient = client;
  IesApiClient({
    this.baseUrl = 'http://localhost:4000',
    this.useRemoteRest = false,
    this.engineProvider,
    this.supabaseTransport,
    this.supabasePublishableKey,
    EisAuthSessionState? initialSessionState,
    http.Client? client,
  })  : _httpClient = client,
        _sessionState =
            initialSessionState ?? const EisAuthSessionState.unauthenticated();

  // bool get isEmbedded => !useRemoteRest && _httpClient == null;
  // Gene - Nov, 20, 2026: Distinguish Serverpod RPC, Embedded Local Engine, and Remote REST transport.
  // bool get isServerpod => serverpodClient != null && _httpClient == null;
  // bool get isEmbedded => !isServerpod && !useRemoteRest && _httpClient == null;
  // EisBackendMode get backendMode => isServerpod
  //     ? EisBackendMode.serverpod
  //     : (isEmbedded ? EisBackendMode.embedded : EisBackendMode.remoteRest);
  // String get modeChipLabel => switch (backendMode) {
  //       EisBackendMode.embedded => 'Local Engine',
  //       EisBackendMode.serverpod => 'Serverpod RPC',
  //       EisBackendMode.remoteRest => 'REST API',
  //     };
  // Gene - Nov, 24, 2026: Distinguish Supabase, Embedded Local Engine, and Remote REST transport.
  bool get isSupabase => supabaseTransport != null && _httpClient == null;

  bool get isEmbedded => !isSupabase && !useRemoteRest && _httpClient == null;

  EisBackendMode get backendMode => isSupabase
      ? EisBackendMode.supabase
      : (isEmbedded ? EisBackendMode.embedded : EisBackendMode.remoteRest);

  String get modeChipLabel => switch (backendMode) {
        EisBackendMode.embedded => 'Local Engine',
        EisBackendMode.supabase => 'Supabase',
        EisBackendMode.remoteRest => 'REST API',
      };

  String get connectionLabel => isEmbedded
      ? 'Local Embedded Engine'
      : (isSupabase ? supabaseTransport!.projectUrl : baseUrl);

  EisAuthSessionState get sessionState => _sessionState;

  WorkspaceMembershipModel? get activeWorkspace => _sessionState.activeWorkspace;

  EisUserRole? get activeRole => _sessionState.activeRole;

  bool get isAuthenticatedInSupabase =>
      !isSupabase || (_sessionState.isAuthenticated && activeWorkspace != null);

  Future<void> dispose() async {
    await supabaseTransport?.dispose();
  }

  String _requireWorkspaceId() {
    final wsId = _sessionState.activeWorkspace?.workspaceId;
    if (wsId == null || wsId.isEmpty) {
      throw StateError(
        'Sign in and select or create a Supabase workspace before accessing EIS data.',
      );
    }
    return wsId;
  }

  Future<EisAuthSessionState> refreshSession({
    String? preferredWorkspaceId,
  }) async {
    if (!isSupabase) {
      return const EisAuthSessionState.unauthenticated();
    }
    _sessionState = await supabaseTransport!.getSessionState(
      preferredWorkspaceId:
          preferredWorkspaceId ?? _sessionState.activeWorkspace?.workspaceId,
    );
    return _sessionState;
  }

  Future<EisAuthSessionState> signInWithSupabase({
    required String email,
    required String password,
  }) async {
    if (!isSupabase) {
      throw StateError('Supabase transport is not active.');
    }
    _sessionState = await supabaseTransport!.signIn(
      email: email,
      password: password,
    );
    return _sessionState;
  }

  Future<EisAuthSessionState> signUpWithSupabase({
    required String email,
    required String password,
  }) async {
    if (!isSupabase) {
      throw StateError('Supabase transport is not active.');
    }
    _sessionState = await supabaseTransport!.signUp(
      email: email,
      password: password,
    );
    return _sessionState;
  }

  Future<void> signOutSupabase() async {
    if (!isSupabase) return;
    await supabaseTransport!.signOut();
    _sessionState = const EisAuthSessionState.unauthenticated();
  }

  Future<WorkspaceMembershipModel> bootstrapSupabaseWorkspace({
    required String workspaceName,
    bool seedDemo = true,
  }) async {
    if (!isSupabase) {
      throw StateError('Supabase transport is not active.');
    }
    final created = await supabaseTransport!.bootstrapWorkspace(
      workspaceName: workspaceName,
      seedDemo: seedDemo,
    );
    _sessionState = await supabaseTransport!.getSessionState(
      preferredWorkspaceId: created.workspaceId,
    );
    return _sessionState.activeWorkspace ?? created;
  }

  void setActiveWorkspace(WorkspaceMembershipModel workspace) {
    _sessionState = EisAuthSessionState(
      isAuthenticated: _sessionState.isAuthenticated,
      userId: _sessionState.userId,
      email: _sessionState.email,
      workspaces: _sessionState.workspaces,
      activeWorkspace: workspace,
    );
  }

  Future<List<WorkspaceMemberRecord>> fetchWorkspaceMembers() async {
    if (!isSupabase) return const [];
    return supabaseTransport!.fetchWorkspaceMembers(
      workspaceId: _requireWorkspaceId(),
    );
  }

  Future<WorkspaceMemberRecord> upsertWorkspaceMember({
    required String email,
    required EisUserRole role,
  }) async {
    if (!isSupabase) {
      throw StateError('Supabase transport is not active.');
    }
    return supabaseTransport!.upsertWorkspaceMember(
      workspaceId: _requireWorkspaceId(),
      email: email,
      role: role,
    );
  }

  Future<Map<String, dynamic>> createWebhookKey({
    required String connector,
    required String label,
  }) async {
    if (!isSupabase) {
      throw StateError('Supabase transport is not active.');
    }
    return supabaseTransport!.createWebhookKey(
      workspaceId: _requireWorkspaceId(),
      connector: connector,
      label: label,
    );
  }

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
    // Gene - Nov, 20, 2026: Route through Serverpod RPC when serverpodClient is active.
    // if (isServerpod) {
    //   final raw =
    //       await serverpodClient!.eis.getDashboardSummary(taxpayerId: taxpayerId);
    //   return DashboardSummaryModel.fromJson(
    //     jsonDecode(raw) as Map<String, dynamic>,
    //   );
    // }
    // Gene - Nov, 24, 2026: Route through Supabase transport when Supabase mode is active.
    if (isSupabase) {
      return supabaseTransport!.fetchDashboard(
        workspaceId: _requireWorkspaceId(),
        taxpayerId: taxpayerId,
      );
    }
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
    // if (isServerpod) {
    //   final raw = await serverpodClient!.eis.getTaxpayers();
    //   final list = jsonDecode(raw) as List<dynamic>;
    //   return list
    //       .map((e) => TaxpayerProfileModel.fromJson(e as Map<String, dynamic>))
    //       .toList();
    // }
    if (isSupabase) {
      return supabaseTransport!.fetchTaxpayers(
        workspaceId: _requireWorkspaceId(),
      );
    }
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
    // if (isServerpod) {
    //   final raw =
    //       await serverpodClient!.eis.getInvoices(taxpayerId: taxpayerId);
    //   final list = jsonDecode(raw) as List<dynamic>;
    //   return list
    //       .map((e) => StoredInvoiceModel.fromJson(e as Map<String, dynamic>))
    //       .toList();
    // }
    if (isSupabase) {
      return supabaseTransport!.fetchInvoices(
        workspaceId: _requireWorkspaceId(),
        taxpayerId: taxpayerId,
      );
    }
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
    // if (isServerpod) {
    //   await serverpodClient!.eis.updateGatewayConfig(
    //     mode: mode,
    //     simulateOutage: simulateOutage,
    //   );
    //   return;
    // }
    if (isSupabase) {
      await supabaseTransport!.updateGatewayConfig(
        workspaceId: _requireWorkspaceId(),
        mode: mode,
        simulateOutage: simulateOutage,
      );
      return;
    }
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
    // if (isServerpod) {
    //   final raw = await serverpodClient!.eis.processRetryQueue();
    //   return jsonDecode(raw) as Map<String, dynamic>;
    // }
    if (isSupabase) {
      return supabaseTransport!.processRetryQueue(
        workspaceId: _requireWorkspaceId(),
      );
    }
    if (isEmbedded) {
      final engine = await _getEngine();
      return await engine.processRetryQueue();
    }
    return await _post('/invoices/retry-queue', {}) as Map<String, dynamic>;
  }

  Future<StoredInvoiceModel> createInvoice(Map<String, dynamic> payload) async {
    // if (isServerpod) {
    //   final raw =
    //       await serverpodClient!.eis.createInvoice(jsonEncode(payload));
    //   return StoredInvoiceModel.fromJson(
    //     jsonDecode(raw) as Map<String, dynamic>,
    //   );
    // }
    if (isSupabase) {
      return supabaseTransport!.createInvoice(
        workspaceId: _requireWorkspaceId(),
        payload: payload,
      );
    }
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
    // if (isServerpod) {
    //   final raw = await serverpodClient!.eis.issueCreditMemo(
    //     invoiceId,
    //     reason: reason,
    //   );
    //   return StoredInvoiceModel.fromJson(
    //     jsonDecode(raw) as Map<String, dynamic>,
    //   );
    // }
    if (isSupabase) {
      return supabaseTransport!.issueCreditMemo(
        workspaceId: _requireWorkspaceId(),
        invoiceId: invoiceId,
        reason: reason,
      );
    }
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
    // if (isServerpod) {
    //   final raw = await serverpodClient!.eis.syncConnector(
    //     connector,
    //     jsonEncode(payload),
    //     taxpayerId: taxpayerId,
    //   );
    //   return StoredInvoiceModel.fromJson(
    //     jsonDecode(raw) as Map<String, dynamic>,
    //   );
    // }
    if (isSupabase) {
      return supabaseTransport!.syncConnector(
        workspaceId: _requireWorkspaceId(),
        connector: connector,
        payload: payload,
        taxpayerId: taxpayerId,
      );
    }
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
    // if (isServerpod) {
    //   return serverpodClient!.eis.importCsvBatch(
    //     csv,
    //     taxpayerId: taxpayerId,
    //   );
    // }
    if (isSupabase) {
      return supabaseTransport!.importCsvBatch(
        workspaceId: _requireWorkspaceId(),
        csv: csv,
        taxpayerId: taxpayerId,
      );
    }
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
    // if (isServerpod) {
    //   final raw = await serverpodClient!.eis.getCasBooks(
    //     taxpayerId: taxpayerId,
    //     bookType: bookType,
    //   );
    //   return CasBooksDataModel.fromJson(
    //     jsonDecode(raw) as Map<String, dynamic>,
    //   );
    // }
    if (isSupabase) {
      return supabaseTransport!.fetchCasBooks(
        workspaceId: _requireWorkspaceId(),
        taxpayerId: taxpayerId,
        bookType: bookType,
      );
    }
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
    // if (isServerpod) {
    //   final raw = await serverpodClient!.eis.generateSlsp(
    //     taxpayerId: taxpayerId,
    //     kind: kind,
    //     period: period,
    //   );
    //   return StatutoryReportModel.fromJson(
    //     jsonDecode(raw) as Map<String, dynamic>,
    //   );
    // }
    if (isSupabase) {
      return supabaseTransport!.fetchSlsp(
        workspaceId: _requireWorkspaceId(),
        taxpayerId: taxpayerId,
        kind: kind,
        period: period,
      );
    }
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
    // if (isServerpod) {
    //   final raw = await serverpodClient!.eis.generateWithholdingDat(
    //     taxpayerId: taxpayerId,
    //     kind: kind,
    //     period: period,
    //   );
    //   return StatutoryReportModel.fromJson(
    //     jsonDecode(raw) as Map<String, dynamic>,
    //   );
    // }
    if (isSupabase) {
      return supabaseTransport!.fetchWithholdingDat(
        workspaceId: _requireWorkspaceId(),
        taxpayerId: taxpayerId,
        kind: kind,
        period: period,
      );
    }
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
    // if (isServerpod) {
    //   final raw = await serverpodClient!.eis.generateForm2307(invoiceId);
    //   return jsonDecode(raw) as Map<String, dynamic>;
    // }
    if (isSupabase) {
      return supabaseTransport!.fetchForm2307(
        workspaceId: _requireWorkspaceId(),
        invoiceId: invoiceId,
      );
    }
    if (isEmbedded) {
      final engine = await _getEngine();
      return engine.generateForm2307ForInvoice(invoiceId);
    }
    return await _get('/statutory/form2307/$invoiceId') as Map<String, dynamic>;
  }

  Future<AuditTrailResponseModel> fetchAuditTrail() async {
    // if (isServerpod) {
    //   final raw = await serverpodClient!.eis.getAuditTrail();
    //   return AuditTrailResponseModel.fromJson(
    //     jsonDecode(raw) as Map<String, dynamic>,
    //   );
    // }
    if (isSupabase) {
      return supabaseTransport!.fetchAuditTrail(
        workspaceId: _requireWorkspaceId(),
      );
    }
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
    // if (isServerpod) {
    //   await serverpodClient!.eis.registerTaxpayer(jsonEncode(body));
    //   return;
    // }
    if (isSupabase) {
      await supabaseTransport!.registerTaxpayer(
        workspaceId: _requireWorkspaceId(),
        body: body,
      );
      return;
    }
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
    // if (isServerpod) {
    //   await serverpodClient!.eis.rotateTaxpayerKeys(taxpayerId);
    //   return;
    // }
    if (isSupabase) {
      await supabaseTransport!.rotateTaxpayerKeys(
        workspaceId: _requireWorkspaceId(),
        taxpayerId: taxpayerId,
      );
      return;
    }
    if (isEmbedded) {
      final engine = await _getEngine();
      engine.rotateTaxpayerKeys(taxpayerId);
      return;
    }
    await _post('/taxpayers/$taxpayerId/rotate-keys', {});
  }
}
