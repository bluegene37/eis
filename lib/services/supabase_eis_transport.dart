// Gene - Nov, 24, 2026: Supabase PostgREST + Auth + Edge Function transport abstraction
// supporting live Supabase Cloud / Self-Hosted deployments and test fakes.

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/bir/cas_books_service.dart';
import '../models/ies_models.dart';
import '../models/workspace_models.dart';

abstract class EisSupabaseTransport {
  String get projectUrl;

  Future<void> dispose();

  Future<EisAuthSessionState> getSessionState({String? preferredWorkspaceId});

  Future<EisAuthSessionState> signIn({
    required String email,
    required String password,
  });

  Future<EisAuthSessionState> signUp({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<WorkspaceMembershipModel> bootstrapWorkspace({
    required String workspaceName,
    bool seedDemo = true,
  });

  Future<List<WorkspaceMemberRecord>> fetchWorkspaceMembers({
    required String workspaceId,
  });

  Future<WorkspaceMemberRecord> upsertWorkspaceMember({
    required String workspaceId,
    required String email,
    required EisUserRole role,
  });

  Future<Map<String, dynamic>> createWebhookKey({
    required String workspaceId,
    required String connector,
    required String label,
  });

  Future<DashboardSummaryModel> fetchDashboard({
    required String workspaceId,
    String? taxpayerId,
  });

  Future<List<TaxpayerProfileModel>> fetchTaxpayers({
    required String workspaceId,
  });

  Future<List<StoredInvoiceModel>> fetchInvoices({
    required String workspaceId,
    String? taxpayerId,
  });

  Future<void> updateGatewayConfig({
    required String workspaceId,
    String? mode,
    bool? simulateOutage,
  });

  Future<Map<String, dynamic>> processRetryQueue({
    required String workspaceId,
  });

  Future<StoredInvoiceModel> createInvoice({
    required String workspaceId,
    required Map<String, dynamic> payload,
  });

  Future<StoredInvoiceModel> issueCreditMemo({
    required String workspaceId,
    required String invoiceId,
    required String reason,
  });

  Future<StoredInvoiceModel> syncConnector({
    required String workspaceId,
    required String connector,
    required Map<String, dynamic> payload,
    String? taxpayerId,
  });

  Future<int> importCsvBatch({
    required String workspaceId,
    required String csv,
    String? taxpayerId,
  });

  Future<CasBooksDataModel> fetchCasBooks({
    required String workspaceId,
    String? taxpayerId,
    String bookType = 'ALL',
  });

  Future<StatutoryReportModel> fetchSlsp({
    required String workspaceId,
    String? taxpayerId,
    required String kind,
    String period = '202611',
  });

  Future<StatutoryReportModel> fetchWithholdingDat({
    required String workspaceId,
    String? taxpayerId,
    required String kind,
    String period = '202612',
  });

  Future<Map<String, dynamic>> fetchForm2307({
    required String workspaceId,
    required String invoiceId,
  });

  Future<AuditTrailResponseModel> fetchAuditTrail({
    required String workspaceId,
  });

  Future<void> registerTaxpayer({
    required String workspaceId,
    required Map<String, dynamic> body,
  });

  Future<void> rotateTaxpayerKeys({
    required String workspaceId,
    required String taxpayerId,
  });
}

class LiveSupabaseEisTransport implements EisSupabaseTransport {
  @override
  final String projectUrl;
  // final SupabaseClient _client;
  //
  // LiveSupabaseEisTransport({
  //   required String url,
  //   required String publishableKey,
  //   SupabaseClient? client,
  // })  : projectUrl = url.replaceAll(RegExp(r'/+$'), ''),
  //       _client =
  //           client ??
  //           SupabaseClient(
  //             url.replaceAll(RegExp(r'/+$'), ''),
  //             publishableKey,
  //           );
  //
  // @override
  // Future<void> dispose() => _client.dispose();
  // Gene - Nov, 24, 2026: Lazily initialize SupabaseClient so constructing transport does not spawn background isolates or refresh timers until used.
  final String publishableKey;
  SupabaseClient? _clientInstance;

  LiveSupabaseEisTransport({
    required String url,
    required this.publishableKey,
    SupabaseClient? client,
  })  : projectUrl = url.replaceAll(RegExp(r'/+$'), ''),
        _clientInstance = client;

  SupabaseClient get _client =>
      _clientInstance ??= SupabaseClient(projectUrl, publishableKey);

  @override
  Future<void> dispose() async {
    final client = _clientInstance;
    _clientInstance = null;
    if (client != null) {
      await client.dispose();
    }
  }

  Future<Map<String, dynamic>> _invokeJson(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.functions.invoke(functionName, body: body);
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      if (data is String && data.trim().isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
      return const {};
    } on FunctionException catch (e) {
      final details = e.details;
      final message = (details is Map && details['error'] != null)
          ? details['error'].toString()
          : (e.reasonPhrase ?? 'Edge Function $functionName failed (${e.status})');
      throw Exception(message);
    }
  }

  @override
  Future<EisAuthSessionState> getSessionState({
    String? preferredWorkspaceId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const EisAuthSessionState.unauthenticated();
    }
    final res = await _invokeJson('eis-workspace', {
      'action': 'me',
      'workspaceId': ?preferredWorkspaceId,
    });
    final rawList = (res['workspaces'] as List<dynamic>?) ?? const [];
    final workspaces = rawList
        .map(
          (e) => WorkspaceMembershipModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    WorkspaceMembershipModel? active;
    if (workspaces.isNotEmpty) {
      if (preferredWorkspaceId != null) {
        active = workspaces
            .where((w) => w.workspaceId == preferredWorkspaceId)
            .firstOrNull;
      }
      active ??= workspaces.first;
    }

    return EisAuthSessionState(
      isAuthenticated: true,
      userId: res['userId']?.toString() ?? user.id,
      email: res['email']?.toString() ?? user.email,
      workspaces: workspaces,
      activeWorkspace: active,
    );
  }

  @override
  Future<EisAuthSessionState> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return getSessionState();
  }

  @override
  Future<EisAuthSessionState> signUp({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    if (res.session == null) {
      throw Exception(
        'Check your email inbox to confirm your account before signing in.',
      );
    }
    return getSessionState();
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<WorkspaceMembershipModel> bootstrapWorkspace({
    required String workspaceName,
    bool seedDemo = true,
  }) async {
    final res = await _invokeJson('eis-workspace', {
      'action': 'bootstrap',
      'workspaceName': workspaceName,
      'seedDemo': seedDemo,
    });
    final membership =
        (res['membership'] as Map?)?.cast<String, dynamic>() ?? const {};
    return WorkspaceMembershipModel.fromJson(membership);
  }

  @override
  Future<List<WorkspaceMemberRecord>> fetchWorkspaceMembers({
    required String workspaceId,
  }) async {
    final res = await _invokeJson('eis-workspace', {
      'action': 'me',
      'workspaceId': workspaceId,
    });
    final raw = (res['members'] as List<dynamic>?) ?? const [];
    return raw
        .map(
          (e) => WorkspaceMemberRecord.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  @override
  Future<WorkspaceMemberRecord> upsertWorkspaceMember({
    required String workspaceId,
    required String email,
    required EisUserRole role,
  }) async {
    final res = await _invokeJson('eis-workspace', {
      'action': 'upsert_member',
      'workspaceId': workspaceId,
      'email': email,
      'role': role.apiValue,
    });
    return WorkspaceMemberRecord.fromJson(res);
  }

  @override
  Future<Map<String, dynamic>> createWebhookKey({
    required String workspaceId,
    required String connector,
    required String label,
  }) async {
    return _invokeJson('eis-workspace', {
      'action': 'create_webhook_key',
      'workspaceId': workspaceId,
      'connector': connector,
      'label': label,
    });
  }

  @override
  Future<DashboardSummaryModel> fetchDashboard({
    required String workspaceId,
    String? taxpayerId,
  }) async {
    final json = await _invokeJson('eis-workspace', {
      'action': 'dashboard',
      'workspaceId': workspaceId,
      'taxpayerId': ?taxpayerId,
    });
    return DashboardSummaryModel.fromJson(json);
  }

  @override
  Future<List<TaxpayerProfileModel>> fetchTaxpayers({
    required String workspaceId,
  }) async {
    final rows = await _client
        .from('taxpayers')
        .select('*, taxpayer_branches(*)')
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: true);

    return rows.map((row) {
      final r = Map<String, dynamic>.from(row);
      final rawBranches = (r['taxpayer_branches'] as List<dynamic>?) ?? const [];
      final branches = rawBranches
          .map((b) {
            final bm = Map<String, dynamic>.from(b as Map);
            return {
              'branchCd': bm['branch_cd'],
              'branchName': bm['branch_name'],
              'address': bm['address'],
              'lastSequence': bm['last_sequence'],
              'invoicePrefix': bm['invoice_prefix'],
            };
          })
          .toList()
        ..sort(
          (a, b) => (a['branchCd']?.toString() ?? '').compareTo(
            b['branchCd']?.toString() ?? '',
          ),
        );

      return TaxpayerProfileModel.fromJson({
        'id': r['id'],
        'workspaceId': r['workspace_id'],
        'tin': r['tin'],
        'taxType': r['tax_type'],
        'registeredName': r['registered_name'],
        'businessName': r['business_name'],
        'email': r['email'],
        'eisCertId': r['eis_cert_id'],
        'pttNumber': r['ptt_number'],
        'keyId': r['key_id'],
        'publicKeyPem': r['public_key_json'],
        'branches': branches,
      });
    }).toList();
  }

  @override
  Future<List<StoredInvoiceModel>> fetchInvoices({
    required String workspaceId,
    String? taxpayerId,
  }) async {
    var query = _client
        .from('invoices')
        .select('*')
        .eq('workspace_id', workspaceId);
    if (taxpayerId != null && taxpayerId.isNotEmpty) {
      query = query.eq('taxpayer_id', taxpayerId);
    }
    final rows = await query.order('created_at', ascending: false);

    return rows.map((row) {
      final r = Map<String, dynamic>.from(row);
      return StoredInvoiceModel.fromJson({
        'id': r['id'],
        'taxpayerId': r['taxpayer_id'],
        'branchCd': r['branch_cd'],
        'sourceSystem': r['source_system'],
        'direction': r['direction'],
        'status': r['status'],
        'retryCount': r['retry_count'],
        'threeDayDeadlineAt': r['three_day_deadline_at'],
        'payload': r['payload'],
        'jwsToken': r['jws_token'],
        'aesEnvelope': r['aes_envelope'],
        'lastReceipt': r['last_receipt'],
      });
    }).toList();
  }

  @override
  Future<void> updateGatewayConfig({
    required String workspaceId,
    String? mode,
    bool? simulateOutage,
  }) async {
    await _invokeJson('eis-workspace', {
      'action': 'update_gateway_config',
      'workspaceId': workspaceId,
      'mode': ?mode,
      'simulateOutage': ?simulateOutage,
    });
  }

  @override
  Future<Map<String, dynamic>> processRetryQueue({
    required String workspaceId,
  }) async {
    return _invokeJson('eis-invoices', {
      'action': 'retry_queue',
      'workspaceId': workspaceId,
    });
  }

  @override
  Future<StoredInvoiceModel> createInvoice({
    required String workspaceId,
    required Map<String, dynamic> payload,
  }) async {
    final json = await _invokeJson('eis-invoices', {
      'action': 'create',
      'workspaceId': workspaceId,
      'payload': payload,
    });
    return StoredInvoiceModel.fromJson(json);
  }

  @override
  Future<StoredInvoiceModel> issueCreditMemo({
    required String workspaceId,
    required String invoiceId,
    required String reason,
  }) async {
    final json = await _invokeJson('eis-invoices', {
      'action': 'credit_memo',
      'workspaceId': workspaceId,
      'invoiceId': invoiceId,
      'reason': reason,
    });
    return StoredInvoiceModel.fromJson(json);
  }

  @override
  Future<StoredInvoiceModel> syncConnector({
    required String workspaceId,
    required String connector,
    required Map<String, dynamic> payload,
    String? taxpayerId,
  }) async {
    final json = await _invokeJson('eis-connectors', {
      'action': connector,
      'workspaceId': workspaceId,
      'taxpayerId': ?taxpayerId,
      'payload': payload,
    });
    return StoredInvoiceModel.fromJson(json);
  }

  @override
  Future<int> importCsvBatch({
    required String workspaceId,
    required String csv,
    String? taxpayerId,
  }) async {
    final json = await _invokeJson('eis-connectors', {
      'action': 'csv',
      'workspaceId': workspaceId,
      'taxpayerId': ?taxpayerId,
      'csv': csv,
    });
    return (json['importedCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<CasBooksDataModel> fetchCasBooks({
    required String workspaceId,
    String? taxpayerId,
    String bookType = 'ALL',
  }) async {
    var query = _client
        .from('cas_journal_entries')
        .select('*, cas_journal_lines(*)')
        .eq('workspace_id', workspaceId);
    if (taxpayerId != null && taxpayerId.isNotEmpty) {
      query = query.eq('taxpayer_id', taxpayerId);
    }
    final rows = await query.order('created_at', ascending: false);

    final allEntries = rows.map((row) {
      final r = Map<String, dynamic>.from(row);
      final rawLines = (r['cas_journal_lines'] as List<dynamic>?) ?? const [];
      final sortedLines = rawLines
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort(
          (a, b) => ((a['line_no'] as num?)?.toInt() ?? 0).compareTo(
            (b['line_no'] as num?)?.toInt() ?? 0,
          ),
        );

      return CasJournalEntryModel.fromJson({
        'id': r['id'],
        'bookType': r['book_type'],
        'entryDate': r['entry_date'],
        'referenceNo': r['reference_no'],
        'eisUniqueId': r['eis_unique_id'],
        'counterpartyName': r['counterparty_name'],
        'particulars': r['particulars'],
        'totalDebit': r['total_debit'],
        'totalCredit': r['total_credit'],
        'lines': sortedLines
            .map(
              (ln) => {
                'accountCode': ln['account_code'],
                'accountName': ln['account_name'],
                'debit': ln['debit'],
                'credit': ln['credit'],
              },
            )
            .toList(),
      });
    }).toList();

    final aggCents = <String, ({int debit, int credit})>{};
    for (final entry in allEntries) {
      for (final ln in entry.lines) {
        final cur = aggCents[ln.accountCode] ?? (debit: 0, credit: 0);
        aggCents[ln.accountCode] = (
          debit: cur.debit + (ln.debit * 100).round(),
          credit: cur.credit + (ln.credit * 100).round(),
        );
      }
    }

    var totalDebitsCents = 0;
    var totalCreditsCents = 0;
    final tbRows = <TrialBalanceRowModel>[];
    for (final acct in pfrsChartOfAccounts) {
      final val = aggCents[acct.code];
      if (val == null) continue;
      totalDebitsCents += val.debit;
      totalCreditsCents += val.credit;
      final netCents = acct.normalBalance == 'DEBIT'
          ? val.debit - val.credit
          : val.credit - val.debit;
      tbRows.add(
        TrialBalanceRowModel(
          accountCode: acct.code,
          accountName: acct.name,
          category: acct.category,
          debitTotal: val.debit / 100.0,
          creditTotal: val.credit / 100.0,
          netBalance: netCents / 100.0,
        ),
      );
    }

    final filteredEntries = (bookType != 'ALL' && bookType != 'GL')
        ? allEntries.where((e) => e.bookType == bookType).toList()
        : allEntries;

    return CasBooksDataModel(
      entries: filteredEntries,
      trialBalanceRows: tbRows,
      totalDebits: totalDebitsCents / 100.0,
      totalCredits: totalCreditsCents / 100.0,
      isBalanced: (totalDebitsCents - totalCreditsCents).abs() <= 1,
    );
  }

  @override
  Future<StatutoryReportModel> fetchSlsp({
    required String workspaceId,
    String? taxpayerId,
    required String kind,
    String period = '202611',
  }) async {
    final json = await _invokeJson('eis-reports', {
      'action': 'slsp',
      'workspaceId': workspaceId,
      'taxpayerId': ?taxpayerId,
      'kind': kind,
      'period': period,
    });
    return StatutoryReportModel.fromJson(json);
  }

  @override
  Future<StatutoryReportModel> fetchWithholdingDat({
    required String workspaceId,
    String? taxpayerId,
    required String kind,
    String period = '202612',
  }) async {
    final json = await _invokeJson('eis-reports', {
      'action': 'withholding',
      'workspaceId': workspaceId,
      'taxpayerId': ?taxpayerId,
      'kind': kind,
      'period': period,
    });
    return StatutoryReportModel.fromJson(json);
  }

  @override
  Future<Map<String, dynamic>> fetchForm2307({
    required String workspaceId,
    required String invoiceId,
  }) async {
    return _invokeJson('eis-reports', {
      'action': 'form2307',
      'workspaceId': workspaceId,
      'invoiceId': invoiceId,
    });
  }

  @override
  Future<AuditTrailResponseModel> fetchAuditTrail({
    required String workspaceId,
  }) async {
    final verificationRaw = await _client.rpc(
      'verify_workspace_audit_trail',
      params: {'p_workspace_id': workspaceId},
    );
    final rows = await _client
        .from('audit_trail_entries')
        .select('*')
        .eq('workspace_id', workspaceId)
        .order('seq', ascending: false)
        .limit(100);

    final verification = verificationRaw is Map
        ? Map<String, dynamic>.from(verificationRaw)
        : <String, dynamic>{'valid': true, 'totalEntries': rows.length};

    final entries = rows.map((row) {
      final r = Map<String, dynamic>.from(row);
      return {
        'seq': r['seq'],
        'id': r['audit_code'],
        'timestamp': r['recorded_at'],
        'actor': r['actor'],
        'action': r['action'],
        'taxpayerTin': r['taxpayer_tin'],
        'entityId': r['entity_id'],
        'details': r['details'],
        'prevHash': r['prev_hash'],
        'entryHash': r['entry_hash'],
      };
    }).toList();

    return AuditTrailResponseModel.fromJson({
      'verification': verification,
      'entries': entries,
    });
  }

  @override
  Future<void> registerTaxpayer({
    required String workspaceId,
    required Map<String, dynamic> body,
  }) async {
    await _invokeJson('eis-taxpayers', {
      'action': 'register',
      'workspaceId': workspaceId,
      ...body,
    });
  }

  @override
  Future<void> rotateTaxpayerKeys({
    required String workspaceId,
    required String taxpayerId,
  }) async {
    await _invokeJson('eis-taxpayers', {
      'action': 'rotate_keys',
      'workspaceId': workspaceId,
      'taxpayerId': taxpayerId,
    });
  }
}
