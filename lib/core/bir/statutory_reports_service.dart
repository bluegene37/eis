// Gene - Nov, 20, 2026: Ported from eis pure-Dart BIR EIS/CAS engine.
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'bir_eis_schema.dart';
import 'tax_calculator_service.dart';

class AuditTrailEntry {
  final int seq;
  final String id;
  final String timestamp;
  final String actor;
  final String action;
  final String taxpayerTin;
  final String entityType;
  final String entityId;
  final String details;
  final String prevHash;
  final String entryHash;

  const AuditTrailEntry({
    required this.seq,
    required this.id,
    required this.timestamp,
    required this.actor,
    required this.action,
    required this.taxpayerTin,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.prevHash,
    required this.entryHash,
  });

  factory AuditTrailEntry.fromJson(Map<String, dynamic> json) =>
      AuditTrailEntry(
        seq: (json['seq'] as num?)?.toInt() ?? 0,
        id: json['id']?.toString() ?? '',
        timestamp: json['timestamp']?.toString() ?? '',
        actor: json['actor']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        taxpayerTin: json['taxpayerTin']?.toString() ?? '',
        entityType: json['entityType']?.toString() ?? '',
        entityId: json['entityId']?.toString() ?? '',
        details: json['details']?.toString() ?? '',
        prevHash: json['prevHash']?.toString() ?? '',
        entryHash: json['entryHash']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'id': id,
        'timestamp': timestamp,
        'actor': actor,
        'action': action,
        'taxpayerTin': taxpayerTin,
        'entityType': entityType,
        'entityId': entityId,
        'details': details,
        'prevHash': prevHash,
        'entryHash': entryHash,
      };
}

Map<String, dynamic> generateSlspReport(
  TaxpayerProfile taxpayer,
  List<StoredInvoiceRecord> records,
  String kind, // SALES | PURCHASES
  String fiscalPeriod,
) {
  final filtered = records
      .where(
        (r) => kind == 'SALES' ? r.direction == 'SALES' : r.direction == 'PURCHASE',
      )
      .toList();
  final headOffice = taxpayer.branches.isNotEmpty
      ? taxpayer.branches.first.address
      : null;

  final totalExempt = round2(
    filtered.fold(0.0, (s, r) => s + r.payload.summary.vatExemptSales),
  );
  final totalZero = round2(
    filtered.fold(0.0, (s, r) => s + r.payload.summary.zeroRatedSales),
  );
  final totalVatable = round2(
    filtered.fold(0.0, (s, r) => s + r.payload.summary.vatableSales),
  );
  final totalVat = round2(
    filtered.fold(0.0, (s, r) => s + r.payload.summary.vatAmt),
  );

  final headerType = kind == 'SALES' ? 'H,S' : 'H,P';
  final detailType = kind == 'SALES' ? 'D,S' : 'D,P';

  final datLines = <String>[
    [
      headerType,
      '"${taxpayer.tin}"',
      '"${taxpayer.registeredName.replaceAll('"', '')}"',
      '""',
      '""',
      '""',
      '"${taxpayer.businessName.replaceAll('"', '')}"',
      '"${headOffice?.street ?? ''} ${headOffice?.barangay ?? ''}"',
      '"${headOffice?.city ?? ''} ${headOffice?.province ?? ''}"',
      totalExempt.toStringAsFixed(2),
      totalZero.toStringAsFixed(2),
      totalVatable.toStringAsFixed(2),
      totalVat.toStringAsFixed(2),
      '"009"',
      fiscalPeriod,
      '12',
    ].join(','),
  ];

  final csvLines = <String>[
    'TAXABLE_MONTH,TIN,REGISTERED_NAME,ADDRESS,EXEMPT_SALES,ZERO_RATED_SALES,TAXABLE_SALES,OUTPUT_INPUT_VAT,REFERENCE_INVOICE',
  ];

  for (final r in filtered) {
    final p = r.payload;
    final partyTin =
        (kind == 'SALES' ? p.buyer.tin : p.seller.tin) ?? '000000000';
    final partyName = kind == 'SALES' ? p.buyer.regNm : p.seller.regNm;
    final partyAddrObj = kind == 'SALES' ? p.buyer.address : p.seller.address;
    final addr = partyAddrObj != null
        ? '${partyAddrObj.street} ${partyAddrObj.city}'.trim()
        : 'PHILIPPINES';

    datLines.add(
      [
        detailType,
        '"$partyTin"',
        '"${partyName.replaceAll('"', '')}"',
        '""',
        '""',
        '""',
        '"${addr.replaceAll('"', '')}"',
        '""',
        p.summary.vatExemptSales.toStringAsFixed(2),
        p.summary.zeroRatedSales.toStringAsFixed(2),
        p.summary.vatableSales.toStringAsFixed(2),
        p.summary.vatAmt.toStringAsFixed(2),
        '"${taxpayer.tin}"',
        '${p.issueDtm.substring(0, 7).replaceAll('-', '')}01',
      ].join(','),
    );

    csvLines.add(
      [
        p.issueDtm.substring(0, 7),
        partyTin,
        '"${partyName.replaceAll('"', '')}"',
        '"${addr.replaceAll('"', '')}"',
        p.summary.vatExemptSales.toStringAsFixed(2),
        p.summary.zeroRatedSales.toStringAsFixed(2),
        p.summary.vatableSales.toStringAsFixed(2),
        p.summary.vatAmt.toStringAsFixed(2),
        p.compInvoiceId,
      ].join(','),
    );
  }

  return {
    'filename': '${taxpayer.tin}${kind == 'SALES' ? 'S' : 'P'}$fiscalPeriod.DAT',
    'datContent': datLines.join('\n'),
    'csvContent': csvLines.join('\n'),
    'rowCount': filtered.length,
  };
}

Map<String, dynamic> generateWithholdingDatReport(
  TaxpayerProfile taxpayer,
  List<StoredInvoiceRecord> records,
  String reportKind, // SAWT | QAP
  String periodQuarter,
) {
  final applicable = records.where((r) {
    if (r.payload.summary.withholdingTaxAmt <= 0) return false;
    return reportKind == 'SAWT'
        ? r.direction == 'SALES'
        : r.direction == 'PURCHASE';
  }).toList();

  final formCode = reportKind == 'SAWT' ? '1702Q' : '1601EQ';
  final headerCode = reportKind == 'SAWT' ? 'HSAWT' : 'HQAP';
  final detailCode = reportKind == 'SAWT' ? 'DSAWT' : 'DQAP';

  final totalBase = round2(
    applicable.fold(0.0, (s, r) => s + r.payload.summary.netSales),
  );
  final totalTaxWithheld = round2(
    applicable.fold(0.0, (s, r) => s + r.payload.summary.withholdingTaxAmt),
  );

  final datLines = <String>[
    [
      headerCode,
      'H$formCode',
      taxpayer.tin,
      '0000',
      '"${taxpayer.registeredName.replaceAll('"', '')}"',
      periodQuarter,
      '009',
    ].join(','),
  ];

  final csvLines = <String>[
    'SEQ,COUNTERPARTY_TIN,BRANCH_CD,REGISTERED_NAME,ATC_CODE,TAX_BASE,TAX_RATE_PCT,TAX_WITHHELD,INVOICE_NO',
  ];

  for (var idx = 0; idx < applicable.length; idx++) {
    final p = applicable[idx].payload;
    final partyTin =
        (reportKind == 'SAWT' ? p.buyer.tin : p.seller.tin) ?? '000000000';
    final partyBranch =
        (reportKind == 'SAWT' ? p.buyer.branchCd : p.seller.branchCd) ?? '0000';
    final partyName = reportKind == 'SAWT' ? p.buyer.regNm : p.seller.regNm;

    final atcItem =
        p.itemList.where((i) => i.atcCode != null).firstOrNull;
    final atc = atcItem?.atcCode ?? 'WC160';
    final ratePct = round2((atcItem?.cwtRate ?? 0.02) * 100);

    datLines.add(
      [
        detailCode,
        'D$formCode',
        idx + 1,
        partyTin,
        partyBranch,
        '"${partyName.replaceAll('"', '')}"',
        periodQuarter,
        atc,
        p.summary.netSales.toStringAsFixed(2),
        ratePct.toStringAsFixed(2),
        p.summary.withholdingTaxAmt.toStringAsFixed(2),
      ].join(','),
    );

    csvLines.add(
      [
        idx + 1,
        partyTin,
        partyBranch,
        '"${partyName.replaceAll('"', '')}"',
        atc,
        p.summary.netSales.toStringAsFixed(2),
        ratePct.toStringAsFixed(2),
        p.summary.withholdingTaxAmt.toStringAsFixed(2),
        p.compInvoiceId,
      ].join(','),
    );
  }

  datLines.add(
    [
      reportKind == 'SAWT' ? 'CSAWT' : 'CQAP',
      'C$formCode',
      taxpayer.tin,
      '0000',
      periodQuarter,
      totalBase.toStringAsFixed(2),
      totalTaxWithheld.toStringAsFixed(2),
    ].join(','),
  );

  return {
    'filename': '${taxpayer.tin}0000$periodQuarter$formCode.DAT',
    'datContent': datLines.join('\n'),
    'csvContent': csvLines.join('\n'),
    'rowCount': applicable.length,
  };
}

Map<String, dynamic> generateBirForm2307(StoredInvoiceRecord record) {
  final p = record.payload;
  final issueDate = DateTime.parse(p.issueDtm);
  final year = issueDate.year;
  final quarterIndex = (issueDate.month - 1) ~/ 3;
  final startMonth = quarterIndex * 3 + 1;
  final monthInQuarter = ((issueDate.month - 1) % 3) + 1;

  final periodFrom = '$year-${startMonth.toString().padLeft(2, '0')}-01';
  final endMonth = startMonth + 2;
  final lastDay = (endMonth == 6 || endMonth == 9) ? '30' : '31';
  final periodTo = '$year-${endMonth.toString().padLeft(2, '0')}-$lastDay';

  final lines = p.itemList.where((i) => i.cwtAmt > 0).map((item) {
    return {
      'atcCode': item.atcCode ?? 'WC160',
      'description': item.itemNm,
      'month1Base': monthInQuarter == 1 ? item.netSales : 0,
      'month2Base': monthInQuarter == 2 ? item.netSales : 0,
      'month3Base': monthInQuarter == 3 ? item.netSales : 0,
      'totalIncomePayment': item.netSales,
      'taxRatePct': round2(item.cwtRate * 100),
      'taxWithheld': item.cwtAmt,
    };
  }).toList();

  final payeeAddr =
      '${p.seller.address.street}, ${p.seller.address.city}, ${p.seller.address.province}';
  final payorAddr = p.buyer.address != null
      ? '${p.buyer.address!.street}, ${p.buyer.address!.city}, ${p.buyer.address!.province}'
      : 'Metro Manila, Philippines';

  final rowsHtml = lines
      .map(
        (l) => '<tr><td>${l['atcCode']}</td><td>${l['description']}</td>'
            '<td>${(l['totalIncomePayment'] as double).toStringAsFixed(2)}</td>'
            '<td>${l['taxRatePct']}%</td>'
            '<td>${(l['taxWithheld'] as double).toStringAsFixed(2)}</td></tr>',
      )
      .join();

  final printableHtml =
      '<!DOCTYPE html><html><head><meta charset="utf-8"><title>BIR Form 2307 - ${p.compInvoiceId}</title>'
      '<style>body{font-family:Arial,sans-serif;font-size:12px;margin:24px;}table{width:100%;border-collapse:collapse;margin-top:12px;}th,td{border:1px solid #333;padding:6px;text-align:left;}th{background:#f1f5f9;}</style></head>'
      '<body><h2>BIR Form No. 2307 - Certificate of Creditable Tax Withheld at Source</h2>'
      '<p><strong>Period:</strong> $periodFrom to $periodTo | <strong>Invoice:</strong> ${p.compInvoiceId} | <strong>EisUniqueId:</strong> ${p.eisUniqueId}</p>'
      '<p><strong>Payee:</strong> ${p.seller.regNm} (TIN: ${p.seller.tin}-${p.seller.branchCd})</p>'
      '<p><strong>Payor (Withholding Agent):</strong> ${p.buyer.regNm} (TIN: ${p.buyer.tin ?? '000000000'}-${p.buyer.branchCd ?? '0000'})</p>'
      '<table><tr><th>ATC</th><th>Income Payment Description</th><th>Total Payment (PHP)</th><th>Rate</th><th>Tax Withheld (PHP)</th></tr>'
      '$rowsHtml'
      '</table><h3>Total Tax Withheld: PHP ${p.summary.withholdingTaxAmt.toStringAsFixed(2)}</h3></body></html>';

  return {
    'formTitle':
        'BIR Form No. 2307 - Certificate of Creditable Tax Withheld at Source',
    'periodFrom': periodFrom,
    'periodTo': periodTo,
    'payee': {
      'tin': p.seller.tin,
      'branchCd': p.seller.branchCd,
      'name': p.seller.regNm,
      'address': payeeAddr,
    },
    'payor': {
      'tin': p.buyer.tin ?? '000000000',
      'branchCd': p.buyer.branchCd ?? '0000',
      'name': p.buyer.regNm,
      'address': payorAddr,
    },
    'referenceInvoice': p.compInvoiceId,
    'eisUniqueId': p.eisUniqueId,
    'lines': lines,
    'totalTaxWithheld': p.summary.withholdingTaxAmt,
    'printableHtml': printableHtml,
  };
}

class AuditTrailService {
  final List<AuditTrailEntry> _entries = [];

  void loadEntries(List<AuditTrailEntry> existing) {
    _entries
      ..clear()
      ..addAll(existing);
  }

  List<AuditTrailEntry> getEntries() => List.unmodifiable(_entries);

  AuditTrailEntry append({
    required String actor,
    required String action,
    required String taxpayerTin,
    required String entityType,
    required String entityId,
    required String details,
  }) {
    final seq = _entries.length + 1;
    final prevHash =
        _entries.isNotEmpty ? _entries.last.entryHash : 'GENESIS-BIR-ANNEX-B';
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final id = 'AUD-${seq.toString().padLeft(6, '0')}';

    final canonical = jsonEncode({
      'seq': seq,
      'id': id,
      'timestamp': timestamp,
      'actor': actor,
      'action': action,
      'taxpayerTin': taxpayerTin,
      'entityType': entityType,
      'entityId': entityId,
      'details': details,
      'prevHash': prevHash,
    });
    final entryHash = sha256.convert(utf8.encode(canonical)).toString();

    final entry = AuditTrailEntry(
      seq: seq,
      id: id,
      timestamp: timestamp,
      actor: actor,
      action: action,
      taxpayerTin: taxpayerTin,
      entityType: entityType,
      entityId: entityId,
      details: details,
      prevHash: prevHash,
      entryHash: entryHash,
    );
    _entries.add(entry);
    return entry;
  }

  Map<String, dynamic> verifyIntegrity() {
    var expectedPrev = 'GENESIS-BIR-ANNEX-B';
    for (final e in _entries) {
      if (e.prevHash != expectedPrev) {
        return {
          'valid': false,
          'totalEntries': _entries.length,
          'brokenAtSeq': e.seq,
        };
      }
      final canonical = jsonEncode({
        'seq': e.seq,
        'id': e.id,
        'timestamp': e.timestamp,
        'actor': e.actor,
        'action': e.action,
        'taxpayerTin': e.taxpayerTin,
        'entityType': e.entityType,
        'entityId': e.entityId,
        'details': e.details,
        'prevHash': e.prevHash,
      });
      final recomputed = sha256.convert(utf8.encode(canonical)).toString();
      if (recomputed != e.entryHash) {
        return {
          'valid': false,
          'totalEntries': _entries.length,
          'brokenAtSeq': e.seq,
        };
      }
      expectedPrev = e.entryHash;
    }
    return {
      'valid': true,
      'totalEntries': _entries.length,
      'brokenAtSeq': null,
    };
  }
}
