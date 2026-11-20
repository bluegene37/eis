// Gene - Nov, 20, 2026: Ported from eis pure-Dart BIR EIS/CAS engine (adapted with web-safe EisStorePersistence).
import 'dart:convert';
// import 'dart:io';
// Gene - Nov, 20, 2026: Replaced direct dart:io File calls with conditional EisStorePersistence so Web and native builds both work cleanly.
import 'dart:math';
import 'bir_eis_schema.dart';
import 'bir_simulator_gateway_service.dart';
import 'cas_books_service.dart';
import 'crypto_jws_aes_service.dart';
import 'erp_connectors_service.dart';
import 'persistence/eis_store_persistence.dart';
import 'statutory_reports_service.dart';
import 'tax_calculator_service.dart';

class EisEngineService {
  final List<TaxpayerProfile> _taxpayers = [];
  final List<StoredInvoiceRecord> _invoices = [];
  final List<CasJournalEntry> _journalEntries = [];
  final BirSimulatorGatewayService gateway = BirSimulatorGatewayService();
  final AuditTrailService auditTrail = AuditTrailService();
  final String? persistPath;
  final EisStorePersistence? _persistence;

  // EisEngineService({this.persistPath}) {
  //   if (persistPath != null && File(persistPath!).existsSync()) {
  //     _loadFromDisk();
  //   }
  // }
  // Gene - Nov, 20, 2026: Load initial snapshot through web-safe EisStorePersistence.
  EisEngineService({this.persistPath, EisStorePersistence? persistence})
      : _persistence = persistence ?? createFilePersistence(persistPath) {
    final raw = _persistence?.readSync();
    if (raw != null && raw.trim().isNotEmpty) {
      _loadFromRaw(raw);
    }
  }

  static String _randomId(String prefix) {
    final rng = Random.secure();
    final hex = List.generate(
      4,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join().toUpperCase();
    return '$prefix-$hex';
  }

  void _saveToDisk() {
    // if (persistPath == null) return;
    // final file = File(persistPath!);
    // if (!file.parent.existsSync()) {
    //   file.parent.createSync(recursive: true);
    // }
    // final snapshot = { ... };
    // file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(snapshot));
    if (_persistence == null) return;
    final snapshot = {
      'taxpayers': _taxpayers.map((t) => t.toJson()).toList(),
      'invoices': _invoices.map((i) => i.toJson()).toList(),
      'journalEntries': _journalEntries.map((j) => j.toJson()).toList(),
      'auditEntries': auditTrail.getEntries().map((a) => a.toJson()).toList(),
    };
    _persistence.writeSync(const JsonEncoder.withIndent('  ').convert(snapshot));
  }

  // void _loadFromDisk() {
  //   final raw = File(persistPath!).readAsStringSync();
  void _loadFromRaw(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _taxpayers
      ..clear()
      ..addAll(
        ((map['taxpayers'] as List<dynamic>?) ?? const [])
            .map((e) => TaxpayerProfile.fromJson(e as Map<String, dynamic>)),
      );
    _invoices
      ..clear()
      ..addAll(
        ((map['invoices'] as List<dynamic>?) ?? const [])
            .map((e) => StoredInvoiceRecord.fromJson(e as Map<String, dynamic>)),
      );
    _journalEntries
      ..clear()
      ..addAll(
        ((map['journalEntries'] as List<dynamic>?) ?? const [])
            .map((e) => CasJournalEntry.fromJson(e as Map<String, dynamic>)),
      );
    auditTrail.loadEntries(
      ((map['auditEntries'] as List<dynamic>?) ?? const [])
          .map((e) => AuditTrailEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    for (final inv in _invoices) {
      if (inv.status == 'TRANSMITTED') {
        gateway.registerKnownEisId(inv.payload.eisUniqueId);
      }
    }
  }

  List<TaxpayerProfile> getTaxpayers() => List.unmodifiable(_taxpayers);

  TaxpayerProfile getTaxpayerById([String? id]) {
    if (id != null && id.isNotEmpty) {
      final found = _taxpayers.where((t) => t.id == id).firstOrNull;
      if (found != null) return found;
    }
    if (_taxpayers.isEmpty) {
      throw StateError('No Taxpayer TIN registered yet.');
    }
    return _taxpayers.first;
  }

  TaxpayerProfile registerTaxpayer({
    String workspaceId = 'WS-PH-DEFAULT',
    required String tin,
    required String taxType,
    required String registeredName,
    required String businessName,
    required String email,
    String? eisCertId,
    String? pttNumber,
    required BirAddress headOfficeAddress,
  }) {
    final normTin = normalizeTin9(tin);
    final cert = (eisCertId != null && eisCertId.isNotEmpty)
        ? eisCertId.toUpperCase().substring(0, min(8, eisCertId.length))
        : 'EC${normTin.substring(0, 6)}';
    final cryptoBundle = generateTaxpayerCryptoBundle(normTin, cert);

    final profile = TaxpayerProfile(
      id: _randomId('TP'),
      workspaceId: workspaceId,
      tin: normTin,
      taxType: taxType,
      registeredName: registeredName.trim(),
      businessName: businessName.trim(),
      email: email.trim(),
      eisCertId: cert,
      pttNumber: pttNumber ?? 'PTT-2026-${normTin.substring(normTin.length - 4)}',
      publicKeyJson: cryptoBundle.publicKeyJson,
      privateKeyJson: cryptoBundle.privateKeyJson,
      aesKeyHex: cryptoBundle.aesKeyHex,
      keyId: cryptoBundle.keyId,
      branches: [
        TaxpayerBranch(
          branchCd: '0000',
          branchName: 'Head Office',
          address: headOfficeAddress,
          lastSequence: 0,
          invoicePrefix: 'SI-0000',
        ),
      ],
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    _taxpayers.add(profile);
    auditTrail.append(
      actor: 'system.admin',
      action: 'REGISTER_TAXPAYER_TIN',
      taxpayerTin: profile.tin,
      entityType: 'TaxpayerProfile',
      entityId: profile.id,
      details:
          'Registered ${profile.registeredName} (TIN ${profile.tin}, Cert ${profile.eisCertId}, RSA-2048 + AES-256 keys provisioned).',
    );
    _saveToDisk();
    return profile;
  }

  TaxpayerBranch addBranch(
    String taxpayerId, {
    required String branchCd,
    required String branchName,
    required BirAddress address,
    String? invoicePrefix,
  }) {
    final tp = getTaxpayerById(taxpayerId);
    final normCd = normalizeBranchCd(branchCd);
    if (tp.branches.any((b) => b.branchCd == normCd)) {
      throw ArgumentError('BranchCd $normCd already exists for TIN ${tp.tin}.');
    }
    final branch = TaxpayerBranch(
      branchCd: normCd,
      branchName: branchName.trim(),
      address: address,
      lastSequence: 0,
      invoicePrefix: invoicePrefix ?? 'SI-$normCd',
    );
    tp.branches.add(branch);
    auditTrail.append(
      actor: 'system.admin',
      action: 'ADD_BRANCH',
      taxpayerTin: tp.tin,
      entityType: 'TaxpayerBranch',
      entityId: normCd,
      details: 'Added Branch $normCd (${branch.branchName}) under TIN ${tp.tin}.',
    );
    _saveToDisk();
    return branch;
  }

  TaxpayerProfile rotateTaxpayerKeys(String taxpayerId) {
    final tp = getTaxpayerById(taxpayerId);
    final bundle = generateTaxpayerCryptoBundle(tp.tin, tp.eisCertId);
    tp.keyId = bundle.keyId;
    tp.publicKeyJson = bundle.publicKeyJson;
    tp.privateKeyJson = bundle.privateKeyJson;
    tp.aesKeyHex = bundle.aesKeyHex;
    auditTrail.append(
      actor: 'security.officer',
      action: 'ROTATE_JWS_AES_KEYS',
      taxpayerTin: tp.tin,
      entityType: 'TaxpayerProfile',
      entityId: tp.id,
      details: 'Rotated RSA-2048 JWS keypair (${tp.keyId}) and AES-256 key.',
    );
    _saveToDisk();
    return tp;
  }

  Future<StoredInvoiceRecord> ingestAndTransmitInvoice(
    CanonicalIngestInput input, {
    bool forceInvalidPayload = false,
  }) async {
    final tp = getTaxpayerById(input.taxpayerId);
    final normBranch = normalizeBranchCd(input.branchCd);
    final branch = tp.branches.where((b) => b.branchCd == normBranch).firstOrNull ??
        tp.branches.first;

    final issueDate =
        (input.issueDtm != null ? DateTime.tryParse(input.issueDtm!) : null) ??
            DateTime.now();

    // branch.lastSequence += 1;
    // final seqNum = branch.lastSequence;
    // final eisUniqueId = buildEisUniqueId(issueDate, tp.eisCertId, seqNum);
    // Gene - Nov, 20, 2026: Use taxpayer-wide monotonic lastEisSequence for EisUniqueId (shared EisCertId) while preserving per-branch sequence for CompInvoiceId.
    branch.lastSequence += 1;
    tp.lastEisSequence += 1;
    final seqNum = branch.lastSequence;
    final eisUniqueId =
        buildEisUniqueId(issueDate, tp.eisCertId, tp.lastEisSequence);
    final compInvoiceId = (input.compInvoiceId != null &&
            input.compInvoiceId!.trim().isNotEmpty)
        ? input.compInvoiceId!.trim()
        : '${branch.invoicePrefix}-${seqNum.toString().padLeft(6, '0')}';

    final computed = computeBirTaxBreakdown(
      input.items,
      tp.taxType,
      buyerCategory: input.buyerCategory,
      otherChargesAmt: input.otherChargesAmt,
    );

    final normBuyerTin = (input.buyerTin != null && input.buyerTin!.isNotEmpty)
        ? normalizeTin9(input.buyerTin!)
        : null;

    final payload = BirEisPayloadV201(
      systemType: input.systemType,
      eisUniqueId: eisUniqueId,
      compInvoiceId: compInvoiceId,
      issueDtm: formatBirDateTime(issueDate),
      docType: input.docType,
      transClass: input.transClass ?? (normBuyerTin != null ? 'B2B' : 'B2C'),
      corrYN: input.corrYN ??
          ((input.docType == '03' || input.docType == '04') ? 'Y' : 'N'),
      refEisUniqueId: input.refEisUniqueId,
      seller: SellerInfo(
        tin: tp.tin,
        branchCd: branch.branchCd,
        type: tp.taxType,
        regNm: tp.registeredName,
        businessNm: tp.businessName,
        address: branch.address,
        email: tp.email,
      ),
      buyer: BuyerInfo(
        tin: forceInvalidPayload ? null : normBuyerTin,
        branchCd:
            normBuyerTin != null ? normalizeBranchCd(input.buyerBranchCd) : null,
        regNm: input.buyerName.trim(),
        address: input.buyerAddress,
        buyerCategory: input.buyerCategory,
        osacaPwdId: input.osacaPwdId,
      ),
      itemList: computed.itemList,
      summary: computed.summary,
    );

    final jwsToken =
        signBirPayloadJws(payload.toJson(), tp.privateKeyJson, tp.keyId);
    final aesEnvelope = encryptJwsWithAes256(jwsToken, tp.aesKeyHex);
    final receipt = await gateway.transmitEnvelope(aesEnvelope, tp);
    final deadline = issueDate.add(const Duration(days: 3));

    final status = receipt.accepted
        ? 'TRANSMITTED'
        : receipt.ackCode == 'NET503'
            ? 'QUEUED_RETRY'
            : 'REJECTED';

    final record = StoredInvoiceRecord(
      id: _randomId('INV'),
      taxpayerId: tp.id,
      branchCd: branch.branchCd,
      sourceSystem: input.sourceSystem,
      externalRefId: input.externalRefId,
      direction: input.direction,
      isPaid: input.isPaid,
      payload: payload,
      jwsToken: jwsToken,
      aesEnvelope: aesEnvelope,
      status: status,
      retryCount: status == 'QUEUED_RETRY' ? 1 : 0,
      nextRetryAt: status == 'QUEUED_RETRY'
          ? DateTime.now()
              .add(const Duration(minutes: 5))
              .toUtc()
              .toIso8601String()
          : null,
      threeDayDeadlineAt: deadline.toUtc().toIso8601String(),
      lastReceipt: receipt,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    _invoices.insert(0, record);

    if (status != 'REJECTED') {
      final newEntries = createJournalEntriesForInvoice(record);
      _journalEntries.insertAll(0, newEntries);
    }

    auditTrail.append(
      actor: 'connector.${input.sourceSystem.toLowerCase()}',
      action: 'EIS_INGEST_$status',
      taxpayerTin: tp.tin,
      entityType: 'Invoice',
      entityId: payload.eisUniqueId,
      details:
          '$compInvoiceId | ${receipt.ackCode} | NetSales PHP ${computed.summary.netSales.toStringAsFixed(2)} | VAT PHP ${computed.summary.vatAmt.toStringAsFixed(2)} | CWT PHP ${computed.summary.withholdingTaxAmt.toStringAsFixed(2)}',
    );

    _saveToDisk();
    return record;
  }

  Future<Map<String, int>> processRetryQueue() async {
    final queued =
        _invoices.where((i) => i.status == 'QUEUED_RETRY').toList();
    var succeeded = 0;
    var stillQueued = 0;

    for (final inv in queued) {
      final tp = getTaxpayerById(inv.taxpayerId);
      final receipt = await gateway.transmitEnvelope(inv.aesEnvelope, tp);
      inv.lastReceipt = receipt;
      inv.retryCount += 1;

      if (receipt.accepted) {
        inv.status = 'TRANSMITTED';
        inv.nextRetryAt = null;
        succeeded += 1;
        auditTrail.append(
          actor: 'worker.retry_queue',
          action: 'EIS_RETRY_TRANSMITTED',
          taxpayerTin: tp.tin,
          entityType: 'Invoice',
          entityId: inv.payload.eisUniqueId,
          details:
              'Recovered via 3-day SLA queue on attempt #${inv.retryCount}: ${receipt.birAckId}',
        );
      } else if (receipt.ackCode == 'NET503') {
        inv.nextRetryAt = DateTime.now()
            .add(const Duration(minutes: 10))
            .toUtc()
            .toIso8601String();
        stillQueued += 1;
      } else {
        inv.status = 'REJECTED';
        inv.nextRetryAt = null;
      }
    }

    _saveToDisk();
    return {
      'processed': queued.length,
      'succeeded': succeeded,
      'stillQueued': stillQueued,
    };
  }

  Future<StoredInvoiceRecord> issueCreditMemo(
    String invoiceId, {
    String reason = 'Sales Return / Price Adjustment',
  }) async {
    final orig = _invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (orig == null) {
      throw ArgumentError('Invoice $invoiceId not found.');
    }
    final p = orig.payload;
    return ingestAndTransmitInvoice(
      CanonicalIngestInput(
        taxpayerId: orig.taxpayerId,
        branchCd: orig.branchCd,
        sourceSystem: 'IES_UI',
        systemType: p.systemType,
        docType: '03',
        transClass: p.transClass,
        direction: orig.direction,
        isPaid: orig.isPaid,
        corrYN: 'Y',
        refEisUniqueId: p.eisUniqueId,
        buyerName: p.buyer.regNm,
        buyerTin: p.buyer.tin,
        buyerBranchCd: p.buyer.branchCd,
        buyerCategory: p.buyer.buyerCategory,
        buyerAddress: p.buyer.address,
        items: p.itemList
            .map(
              (i) => RawLineItemInput(
                itemCd: i.itemCd,
                itemNm: '${i.itemNm} ($reason)',
                unit: i.unit,
                qty: i.qty,
                unitPrice: i.unitCost,
                taxClassification: i.taxClassification,
                regularDiscountAmt: i.discountAmt,
                atcCode: i.atcCode,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<StoredInvoiceRecord> ingestFromXero(
    Map<String, dynamic> payload, {
    String? taxpayerId,
  }) =>
      ingestAndTransmitInvoice(mapXeroToCanonical(payload, taxpayerId: taxpayerId));

  Future<StoredInvoiceRecord> ingestFromQuickBooks(
    Map<String, dynamic> payload, {
    String? taxpayerId,
  }) =>
      ingestAndTransmitInvoice(
        mapQuickBooksToCanonical(payload, taxpayerId: taxpayerId),
      );

  Future<StoredInvoiceRecord> ingestFromOdoo(
    Map<String, dynamic> payload, {
    String? taxpayerId,
  }) =>
      ingestAndTransmitInvoice(mapOdooToCanonical(payload, taxpayerId: taxpayerId));

  Future<List<StoredInvoiceRecord>> ingestFromCsvBatch(
    String csvText, {
    String? taxpayerId,
  }) async {
    final items = parseCsvBatchToCanonical(csvText, taxpayerId: taxpayerId);
    final results = <StoredInvoiceRecord>[];
    for (final item in items) {
      results.add(await ingestAndTransmitInvoice(item));
    }
    return results;
  }

  List<StoredInvoiceRecord> getInvoices([String? taxpayerId]) {
    if (taxpayerId == null || taxpayerId.isEmpty) {
      return List.unmodifiable(_invoices);
    }
    return _invoices.where((i) => i.taxpayerId == taxpayerId).toList();
  }

  Map<String, dynamic> getCasBooks({
    String? taxpayerId,
    String bookType = 'ALL',
  }) {
    var entries = _journalEntries.toList();
    if (taxpayerId != null && taxpayerId.isNotEmpty) {
      entries = entries.where((e) => e.taxpayerId == taxpayerId).toList();
    }
    if (bookType != 'ALL' && bookType != 'GL') {
      entries = entries.where((e) => e.bookType == bookType).toList();
    }
    final tb = computeTrialBalance(
      (taxpayerId != null && taxpayerId.isNotEmpty)
          ? _journalEntries.where((e) => e.taxpayerId == taxpayerId).toList()
          : _journalEntries,
    );

    return {
      'chartOfAccounts': pfrsChartOfAccounts.map((a) => a.toJson()).toList(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'trialBalance': {
        'rows': tb.rows.map((r) => r.toJson()).toList(),
        'totalDebits': tb.totalDebits,
        'totalCredits': tb.totalCredits,
        'isBalanced': tb.isBalanced,
      },
    };
  }

  Map<String, dynamic> getDashboardSummary([String? taxpayerId]) {
    final invs = getInvoices(taxpayerId);
    final transmitted = invs.where((i) => i.status == 'TRANSMITTED').length;
    final queuedRetry = invs.where((i) => i.status == 'QUEUED_RETRY').length;
    final rejected = invs.where((i) => i.status == 'REJECTED').length;

    final salesInvs =
        invs.where((i) => i.direction == 'SALES' && i.payload.docType != '03');
    final totalSales = round2(
      salesInvs.fold(0.0, (s, i) => s + i.payload.summary.netSales),
    );
    final totalOutputVat = round2(
      salesInvs.fold(0.0, (s, i) => s + i.payload.summary.vatAmt),
    );
    final totalCwt = round2(
      invs.fold(0.0, (s, i) => s + i.payload.summary.withholdingTaxAmt),
    );

    final bySource = <String, int>{};
    for (final inv in invs) {
      bySource[inv.sourceSystem] = (bySource[inv.sourceSystem] ?? 0) + 1;
    }

    return {
      'gatewayConfig': gateway.config.toJson(),
      'taxpayerCount': _taxpayers.length,
      'invoiceCounts': {
        'total': invs.length,
        'transmitted': transmitted,
        'queuedRetry': queuedRetry,
        'rejected': rejected,
      },
      'financialsPhp': {
        'totalSales': totalSales,
        'totalOutputVat': totalOutputVat,
        'totalCwt': totalCwt,
      },
      'bySource': bySource,
      'auditChain': auditTrail.verifyIntegrity(),
      'atcCatalog': birAtcCatalog.values.map((a) => a.toJson()).toList(),
    };
  }

  Map<String, dynamic> generateSlsp(
    String? taxpayerId,
    String kind, {
    String period = '202611',
  }) {
    final tp = getTaxpayerById(taxpayerId);
    final records = getInvoices(tp.id);
    final report = generateSlspReport(tp, records, kind, period);
    auditTrail.append(
      actor: 'tax.accountant',
      action: 'EXPORT_SLSP_$kind',
      taxpayerTin: tp.tin,
      entityType: 'StatutoryReport',
      entityId: report['filename'].toString(),
      details:
          'Generated BIR RELIEF SLSP ($kind) ${report['filename']} with ${report['rowCount']} record(s).',
    );
    _saveToDisk();
    return report;
  }

  Map<String, dynamic> generateWithholdingDat(
    String? taxpayerId,
    String kind, {
    String period = '202612',
  }) {
    final tp = getTaxpayerById(taxpayerId);
    final records = getInvoices(tp.id);
    final report = generateWithholdingDatReport(tp, records, kind, period);
    auditTrail.append(
      actor: 'tax.accountant',
      action: 'EXPORT_${kind}_DAT',
      taxpayerTin: tp.tin,
      entityType: 'StatutoryReport',
      entityId: report['filename'].toString(),
      details:
          'Generated BIR $kind ${report['filename']} with ${report['rowCount']} record(s).',
    );
    _saveToDisk();
    return report;
  }

  Map<String, dynamic> generateForm2307ForInvoice(String invoiceId) {
    final inv = _invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (inv == null) {
      throw ArgumentError('Invoice $invoiceId not found.');
    }
    return generateBirForm2307(inv);
  }

  BirGatewayConfig setGatewayConfig({String? mode, bool? simulateOutage}) {
    if (mode != null) gateway.config.mode = mode;
    if (simulateOutage != null) gateway.config.simulateOutage = simulateOutage;

    final tp = _taxpayers.firstOrNull;
    if (tp != null) {
      auditTrail.append(
        actor: 'system.admin',
        action: 'UPDATE_BIR_GATEWAY',
        taxpayerTin: tp.tin,
        entityType: 'GatewayConfig',
        entityId: gateway.config.mode,
        details:
            'Gateway Mode=${gateway.config.mode}, SimulateOutage=${gateway.config.simulateOutage}',
      );
    }
    _saveToDisk();
    return gateway.config;
  }

  Future<void> seedDefaultDemoDataIfEmpty() async {
    if (_taxpayers.isNotEmpty) return;

    final tp = registerTaxpayer(
      tin: '009123456',
      taxType: 'VAT',
      registeredName: 'Mabuhay Tech & Solutions Inc.',
      businessName: 'Mabuhay Tech PH',
      email: 'compliance@mabuhaytech.ph',
      eisCertId: 'EISC2026',
      pttNumber: 'PTT-RDO044-2026-0881',
      headOfficeAddress: const BirAddress(
        street: '24F Ayala Tower One, Ayala Ave',
        barangay: 'Bel-Air',
        city: 'Makati City',
        province: 'Metro Manila',
        zipCode: '1226',
      ),
    );

    addBranch(
      tp.id,
      branchCd: '0001',
      branchName: 'BGC Bonifacio High Street POS Branch',
      address: const BirAddress(
        street: '9th Ave cor High Street',
        barangay: 'Fort Bonifacio',
        city: 'Taguig City',
        province: 'Metro Manila',
        zipCode: '1634',
      ),
    );

    await ingestAndTransmitInvoice(
      CanonicalIngestInput(
        taxpayerId: tp.id,
        branchCd: '0000',
        sourceSystem: 'IES_UI',
        systemType: 'CAS',
        docType: '02',
        transClass: 'B2B',
        buyerName: 'Bayanihan Retail Holdings Corp.',
        buyerTin: '008445566',
        buyerBranchCd: '0000',
        buyerAddress: const BirAddress(
          street: 'Ortigas Center, Emerald Ave',
          barangay: 'San Antonio',
          city: 'Pasig City',
          province: 'Metro Manila',
          zipCode: '1605',
        ),
        items: const [
          RawLineItemInput(
            itemCd: 'SRV-ERP-01',
            itemNm: 'Annual BIR CAS & EIS Integration Retainer',
            unit: 'LOT',
            qty: 1,
            unitPrice: 120000,
            taxClassification: 'VATABLE',
            atcCode: 'WC160',
          ),
        ],
      ),
    );

    await ingestAndTransmitInvoice(
      const CanonicalIngestInput(
        branchCd: '0001',
        sourceSystem: 'IES_UI',
        systemType: 'POS',
        docType: '01',
        transClass: 'B2C',
        isPaid: true,
        buyerName: 'Juanita Dela Cruz',
        buyerCategory: 'SENIOR_CITIZEN',
        osacaPwdId: 'OSCA-MAKATI-88412',
        items: [
          RawLineItemInput(
            itemCd: 'MED-DEV-02',
            itemNm: 'Ergonomic Wellness & Assistive Terminal',
            unit: 'PCS',
            qty: 1,
            unitPrice: 5600,
            priceIncludesVat: true,
            taxClassification: 'VATABLE',
          ),
        ],
      ),
    );

    await ingestFromXero(
      {
        'InvoiceID': 'xero-inv-9001',
        'InvoiceNumber': 'XERO-2026-104',
        'Type': 'ACCREC',
        'Status': 'AUTHORISED',
        'Contact': {
          'Name': 'Pacific Rim Logistics Pte Ltd (PEZA Zero-Rated)',
          'TaxNumber': '007778899',
          'Addresses': [
            {
              'AddressLine1': 'Laguna Technopark',
              'City': 'Biñan',
              'Region': 'Laguna',
              'PostalCode': '4024',
            },
          ],
        },
        'LineItems': [
          {
            'ItemCode': 'CLOUD-EXPORT',
            'Description': 'Cross-border Cloud Data Engineering',
            'Quantity': 1,
            'UnitAmount': 85000,
            'TaxType': 'ZERORATEDOUTPUT',
          },
        ],
      },
      taxpayerId: tp.id,
    );

    await ingestFromQuickBooks(
      {
        'Id': 'qbo-bill-442',
        'DocNumber': 'QBO-BILL-2026-77',
        'TxnType': 'Bill',
        'CustomerRef': {
          'name': 'Rizal Cloud Infrastructure Inc.',
          'tin': '006554433',
          'branchCd': '0000',
        },
        'Line': [
          {
            'Description': 'Dedicated PH Server Hosting (BIR Static IP Egress)',
            'SalesItemLineDetail': {
              'ItemRef': {'value': 'HOST-PH', 'name': 'Dedicated Server'},
              'Qty': 1,
              'UnitPrice': 25000,
              'TaxCodeRef': {'value': 'VAT12'},
              'AtcCode': 'WC160',
            },
          },
        ],
      },
      taxpayerId: tp.id,
    );

    await ingestFromOdoo(
      {
        'id': 7021,
        'name': 'INV/2026/0019',
        'move_type': 'out_invoice',
        'partner_id': {
          'name': 'Cebu Harbor Trading Corp.',
          'vat': '005332211',
          'street': 'SRP Coastal Road',
          'city': 'Cebu City',
          'zip': '6000',
        },
        'invoice_line_ids': [
          {
            'product_code': 'ODOO-LIC',
            'name': 'Enterprise POS Terminal Subscription',
            'quantity': 5,
            'price_unit': 4500,
            'tax_ids': ['VAT_12'],
            'l10n_ph_atc': 'WC160',
          },
        ],
      },
      taxpayerId: tp.id,
    );
  }
}
