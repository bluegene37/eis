// Gene - Nov, 24, 2026: Unit & widget verification suite for Supabase backend mode,
// Workspace RBAC permissions, Auth gate transitions, and full IesApiClient delegation.

import 'package:eis/core/bir/bir_eis_schema.dart';
import 'package:eis/core/bir/eis_engine_service.dart';
import 'package:eis/core/bir/erp_connectors_service.dart';
import 'package:eis/main.dart';
import 'package:eis/models/ies_models.dart';
import 'package:eis/models/workspace_models.dart';
import 'package:eis/screens/supabase_auth_screen.dart';
import 'package:eis/services/ies_api_client.dart';
import 'package:eis/services/supabase_eis_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class FakeSupabaseEisTransport implements EisSupabaseTransport {
  @override
  final String projectUrl;

  final EisEngineService engine = EisEngineService(persistPath: null);
  final List<WorkspaceMembershipModel> _workspaces = [];
  final List<WorkspaceMemberRecord> _members = [];

  bool _authenticated = false;
  String? _userId;
  String? _email;
  String? lastRotatedTaxpayerId;
  String? lastWorkspaceIdSeen;

  FakeSupabaseEisTransport({
    this.projectUrl = 'https://example.supabase.co',
  });

  @override
  Future<void> dispose() async {}

  Future<void> _ensureSeededWorkspace({
    String workspaceName = 'Mabuhay PH Demo Workspace',
    bool seedDemo = true,
  }) async {
    if (_workspaces.isEmpty) {
      const ws = WorkspaceMembershipModel(
        workspaceId: '11111111-1111-1111-1111-111111111111',
        workspaceCode: 'WS-MABUHAY-01',
        workspaceName: 'Mabuhay PH Demo Workspace',
        role: EisUserRole.admin,
        email: 'admin@example.com',
      );
      _workspaces.add(
        WorkspaceMembershipModel(
          workspaceId: ws.workspaceId,
          workspaceCode: ws.workspaceCode,
          workspaceName: workspaceName,
          role: EisUserRole.admin,
          email: _email ?? ws.email,
        ),
      );
      _members.add(
        WorkspaceMemberRecord(
          id: 'mem-1',
          userId: _userId ?? 'user-1',
          email: _email ?? 'admin@example.com',
          role: EisUserRole.admin,
          createdAt: '2026-11-24T00:00:00Z',
        ),
      );
    }
    if (seedDemo) {
      await engine.seedDefaultDemoDataIfEmpty();
    }
  }

  @override
  Future<EisAuthSessionState> getSessionState({
    String? preferredWorkspaceId,
  }) async {
    if (!_authenticated) {
      return const EisAuthSessionState.unauthenticated();
    }
    WorkspaceMembershipModel? active;
    if (_workspaces.isNotEmpty) {
      if (preferredWorkspaceId != null) {
        active = _workspaces
            .where((w) => w.workspaceId == preferredWorkspaceId)
            .firstOrNull;
      }
      active ??= _workspaces.first;
    }
    return EisAuthSessionState(
      isAuthenticated: true,
      userId: _userId,
      email: _email,
      workspaces: List.unmodifiable(_workspaces),
      activeWorkspace: active,
    );
  }

  @override
  Future<EisAuthSessionState> signIn({
    required String email,
    required String password,
  }) async {
    _authenticated = true;
    _userId = 'user-1';
    _email = email;
    await _ensureSeededWorkspace();
    return getSessionState();
  }

  @override
  Future<EisAuthSessionState> signUp({
    required String email,
    required String password,
  }) async {
    _authenticated = true;
    _userId = 'user-1';
    _email = email;
    return getSessionState();
  }

  @override
  Future<void> signOut() async {
    _authenticated = false;
    _userId = null;
    _email = null;
  }

  @override
  Future<WorkspaceMembershipModel> bootstrapWorkspace({
    required String workspaceName,
    bool seedDemo = true,
  }) async {
    await _ensureSeededWorkspace(
      workspaceName: workspaceName,
      seedDemo: seedDemo,
    );
    return _workspaces.last;
  }

  @override
  Future<List<WorkspaceMemberRecord>> fetchWorkspaceMembers({
    required String workspaceId,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return List.unmodifiable(_members);
  }

  @override
  Future<WorkspaceMemberRecord> upsertWorkspaceMember({
    required String workspaceId,
    required String email,
    required EisUserRole role,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    final rec = WorkspaceMemberRecord(
      id: 'mem-${_members.length + 1}',
      userId: 'user-${_members.length + 1}',
      email: email,
      role: role,
      createdAt: '2026-11-24T00:00:00Z',
    );
    _members.removeWhere((m) => m.email == email);
    _members.add(rec);
    return rec;
  }

  @override
  Future<Map<String, dynamic>> createWebhookKey({
    required String workspaceId,
    required String connector,
    required String label,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return {
      'apiKey': 'eis_wh_test_placeholder_only',
      'keyPrefix': 'eis_wh_test',
      'connector': connector,
      'label': label,
    };
  }

  @override
  Future<DashboardSummaryModel> fetchDashboard({
    required String workspaceId,
    String? taxpayerId,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return DashboardSummaryModel.fromJson(
      engine.getDashboardSummary(taxpayerId),
    );
  }

  @override
  Future<List<TaxpayerProfileModel>> fetchTaxpayers({
    required String workspaceId,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return engine
        .getTaxpayers()
        .map((tp) => TaxpayerProfileModel.fromJson(tp.toJson(includePrivate: false)))
        .toList();
  }

  @override
  Future<List<StoredInvoiceModel>> fetchInvoices({
    required String workspaceId,
    String? taxpayerId,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return engine
        .getInvoices(taxpayerId)
        .map((inv) => StoredInvoiceModel.fromJson(inv.toJson()))
        .toList();
  }

  @override
  Future<void> updateGatewayConfig({
    required String workspaceId,
    String? mode,
    bool? simulateOutage,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    engine.setGatewayConfig(mode: mode, simulateOutage: simulateOutage);
  }

  @override
  Future<Map<String, dynamic>> processRetryQueue({
    required String workspaceId,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return engine.processRetryQueue();
  }

  @override
  Future<StoredInvoiceModel> createInvoice({
    required String workspaceId,
    required Map<String, dynamic> payload,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    final record = await engine.ingestAndTransmitInvoice(
      CanonicalIngestInput.fromJson(payload),
      forceInvalidPayload: payload['forceInvalidPayload'] == true,
    );
    return StoredInvoiceModel.fromJson(record.toJson());
  }

  @override
  Future<StoredInvoiceModel> issueCreditMemo({
    required String workspaceId,
    required String invoiceId,
    required String reason,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    final cm = await engine.issueCreditMemo(invoiceId, reason: reason);
    return StoredInvoiceModel.fromJson(cm.toJson());
  }

  @override
  Future<StoredInvoiceModel> syncConnector({
    required String workspaceId,
    required String connector,
    required Map<String, dynamic> payload,
    String? taxpayerId,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    final rec = switch (connector) {
      'xero' => await engine.ingestFromXero(payload, taxpayerId: taxpayerId),
      'quickbooks' =>
        await engine.ingestFromQuickBooks(payload, taxpayerId: taxpayerId),
      'odoo' => await engine.ingestFromOdoo(payload, taxpayerId: taxpayerId),
      _ => throw ArgumentError('Unsupported connector: $connector'),
    };
    return StoredInvoiceModel.fromJson(rec.toJson());
  }

  @override
  Future<int> importCsvBatch({
    required String workspaceId,
    required String csv,
    String? taxpayerId,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    final list = await engine.ingestFromCsvBatch(csv, taxpayerId: taxpayerId);
    return list.length;
  }

  @override
  Future<CasBooksDataModel> fetchCasBooks({
    required String workspaceId,
    String? taxpayerId,
    String bookType = 'ALL',
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return CasBooksDataModel.fromJson(
      engine.getCasBooks(taxpayerId: taxpayerId, bookType: bookType),
    );
  }

  @override
  Future<StatutoryReportModel> fetchSlsp({
    required String workspaceId,
    String? taxpayerId,
    required String kind,
    String period = '202611',
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return StatutoryReportModel.fromJson(
      engine.generateSlsp(taxpayerId, kind, period: period),
    );
  }

  @override
  Future<StatutoryReportModel> fetchWithholdingDat({
    required String workspaceId,
    String? taxpayerId,
    required String kind,
    String period = '202612',
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return StatutoryReportModel.fromJson(
      engine.generateWithholdingDat(taxpayerId, kind, period: period),
    );
  }

  @override
  Future<Map<String, dynamic>> fetchForm2307({
    required String workspaceId,
    required String invoiceId,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return engine.generateForm2307ForInvoice(invoiceId);
  }

  @override
  Future<AuditTrailResponseModel> fetchAuditTrail({
    required String workspaceId,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    return AuditTrailResponseModel.fromJson({
      'verification': engine.auditTrail.verifyIntegrity(),
      'entries': engine.auditTrail
          .getEntries()
          .reversed
          .map((e) => e.toJson())
          .toList(),
    });
  }

  @override
  Future<void> registerTaxpayer({
    required String workspaceId,
    required Map<String, dynamic> body,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    engine.registerTaxpayer(
      workspaceId: workspaceId,
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
  }

  @override
  Future<void> rotateTaxpayerKeys({
    required String workspaceId,
    required String taxpayerId,
  }) async {
    lastWorkspaceIdSeen = workspaceId;
    lastRotatedTaxpayerId = taxpayerId;
    engine.rotateTaxpayerKeys(taxpayerId);
  }
}

void main() {
  test('EisUserRole enforces least-privilege RBAC matrix for all 5 roles', () {
    expect(EisUserRole.admin.canManageMembers, isTrue);
    expect(EisUserRole.admin.canRotateKeys, isTrue);
    expect(EisUserRole.admin.canIssueInvoice, isTrue);

    expect(EisUserRole.accountant.canIssueInvoice, isTrue);
    expect(EisUserRole.accountant.canManageTaxpayers, isTrue);
    expect(EisUserRole.accountant.canExportReports, isTrue);
    expect(EisUserRole.accountant.canRotateKeys, isFalse);
    expect(EisUserRole.accountant.canManageMembers, isFalse);

    expect(EisUserRole.cashier.canIssueInvoice, isTrue);
    expect(EisUserRole.cashier.canManageTaxpayers, isFalse);
    expect(EisUserRole.cashier.canExportReports, isFalse);
    expect(EisUserRole.cashier.canRotateKeys, isFalse);

    expect(EisUserRole.auditor.canExportReports, isTrue);
    expect(EisUserRole.auditor.canIssueInvoice, isFalse);
    expect(EisUserRole.auditor.canManageTaxpayers, isFalse);

    expect(EisUserRole.securityOfficer.canRotateKeys, isTrue);
    expect(EisUserRole.securityOfficer.canManageGateway, isTrue);
    expect(EisUserRole.securityOfficer.canIssueInvoice, isFalse);
    expect(EisUserRole.securityOfficer.canManageMembers, isFalse);
  });

  test(
      'IesApiClient delegates all BIR EIS, CAS, RBAC, and Auth calls in Supabase mode',
      () async {
    final transport = FakeSupabaseEisTransport();
    final api = IesApiClient(
      baseUrl: transport.projectUrl,
      supabaseTransport: transport,
    );

    expect(api.isSupabase, isTrue);
    expect(api.isEmbedded, isFalse);
    expect(api.backendMode, EisBackendMode.supabase);
    expect(api.modeChipLabel, 'Supabase');

    final unauth = await api.refreshSession();
    expect(unauth.isAuthenticated, isFalse);

    await api.signUpWithSupabase(
      email: 'admin@example.com',
      password: 'Password123!',
    );
    final ws = await api.bootstrapSupabaseWorkspace(
      workspaceName: 'Test PH Workspace',
      seedDemo: true,
    );
    expect(ws.workspaceName, 'Test PH Workspace');
    expect(api.activeRole, EisUserRole.admin);

    final taxpayers = await api.fetchTaxpayers();
    expect(taxpayers, isNotEmpty);
    final tpId = taxpayers.first.id;

    final summary = await api.fetchDashboard(taxpayerId: tpId);
    expect(summary.totalInvoices, 5);
    expect(summary.auditChainValid, isTrue);

    final created = await api.createInvoice({
      'taxpayerId': tpId,
      'branchCd': '0000',
      'sourceSystem': 'IES_UI',
      'systemType': 'CAS',
      'docType': '01',
      'transClass': 'B2B',
      'buyerName': 'Sample PH Buyer Corp.',
      'buyerTin': '008999111',
      'items': [
        {
          'itemNm': 'Enterprise Consulting',
          'qty': 1,
          'unitPrice': 10000,
          'taxClassification': 'VATABLE',
          'atcCode': 'WC160',
        },
      ],
    });
    expect(created.status, 'TRANSMITTED');

    final cm = await api.issueCreditMemo(created.id, 'Price Adjustment');
    expect(cm.docType, '03');

    await api.updateGatewayConfig(simulateOutage: true);
    final queued = await api.createInvoice({
      'taxpayerId': tpId,
      'branchCd': '0000',
      'sourceSystem': 'IES_UI',
      'systemType': 'POS',
      'docType': '01',
      'transClass': 'B2C',
      'buyerName': 'Walk-in Customer',
      'items': [
        {'itemNm': 'POS Hardware', 'qty': 1, 'unitPrice': 2000},
      ],
    });
    expect(queued.status, 'QUEUED_RETRY');

    await api.updateGatewayConfig(simulateOutage: false);
    final retryRes = await api.processRetryQueue();
    expect(retryRes['succeeded'], 1);

    final synced = await api.syncConnector(
      'xero',
      {
        'InvoiceID': 'xero-sb-1',
        'InvoiceNumber': 'XERO-SB-1',
        'Type': 'ACCREC',
        'Status': 'AUTHORISED',
        'Contact': {'Name': 'Xero Buyer', 'TaxNumber': '007111222'},
        'LineItems': [
          {'Description': 'Service', 'Quantity': 1, 'UnitAmount': 5000},
        ],
      },
      taxpayerId: tpId,
    );
    expect(synced.sourceSystem, 'XERO');

    final csvCount = await api.importCsvBatch(
      'CompInvoiceId,BuyerName,BuyerTin,DocType,TransClass,ItemNm,Qty,UnitPrice,TaxClassification,AtcCode\n'
      'CSV-SB-1,Manila Client,006111222,01,B2B,Paper Roll,2,500,VATABLE,WC158',
      taxpayerId: tpId,
    );
    expect(csvCount, 1);

    final invoices = await api.fetchInvoices(taxpayerId: tpId);
    expect(invoices.length, 10);

    final cas = await api.fetchCasBooks(taxpayerId: tpId);
    expect(cas.isBalanced, isTrue);

    final slsp = await api.fetchSlsp(taxpayerId: tpId, kind: 'SALES');
    expect(slsp.datContent, contains('H,S'));

    final sawt = await api.fetchWithholdingDat(taxpayerId: tpId, kind: 'SAWT');
    expect(sawt.datContent, contains('HSAWT'));

    final f2307 = await api.fetchForm2307(created.id);
    expect(f2307['referenceInvoice'], created.compInvoiceId);

    final audit = await api.fetchAuditTrail();
    expect(audit.valid, isTrue);

    await api.registerTaxpayer({
      'tin': '009888777',
      'taxType': 'VAT',
      'registeredName': 'Second PH Corp',
      'businessName': 'Second PH',
      'email': 'tax@secondph.example',
    });
    expect((await api.fetchTaxpayers()).length, 2);

    await api.rotateTaxpayerKeys(tpId);
    expect(transport.lastRotatedTaxpayerId, tpId);

    final addedMember = await api.upsertWorkspaceMember(
      email: 'cashier@example.com',
      role: EisUserRole.cashier,
    );
    expect(addedMember.role, EisUserRole.cashier);
    expect((await api.fetchWorkspaceMembers()).length, 2);

    final whKey = await api.createWebhookKey(
      connector: 'xero',
      label: 'Xero Live Webhook',
    );
    expect(whKey['connector'], 'xero');

    await api.signOutSupabase();
    expect(api.sessionState.isAuthenticated, isFalse);
  });

  testWidgets(
      'Supabase mode shows Auth screen when unauthenticated, signs into workspace, and signs out cleanly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final transport = FakeSupabaseEisTransport();
    final api = IesApiClient(
      baseUrl: transport.projectUrl,
      supabaseTransport: transport,
    );

    await tester.pumpWidget(IesApp(apiClient: api));
    await tester.pumpAndSettle();

    expect(find.byType(SupabaseAuthScreen), findsOneWidget);
    expect(find.text('Sign In to Workspace'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Work Email'),
      'admin@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Password123!',
    );
    await tester.tap(find.text('Sign In to Workspace'));
    await tester.pumpAndSettle();

    expect(find.byType(SupabaseAuthScreen), findsNothing);
    expect(find.text('Supabase'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);

    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Workspace •'), findsOneWidget);

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    expect(find.byType(SupabaseAuthScreen), findsOneWidget);
  });
}
