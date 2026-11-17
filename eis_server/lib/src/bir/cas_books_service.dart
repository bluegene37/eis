import 'dart:math';
import 'bir_eis_schema.dart';
import 'tax_calculator_service.dart';

class ChartOfAccountItem {
  final String code;
  final String name;
  final String category; // ASSET | LIABILITY | EQUITY | REVENUE | EXPENSE
  final String normalBalance; // DEBIT | CREDIT

  const ChartOfAccountItem({
    required this.code,
    required this.name,
    required this.category,
    required this.normalBalance,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'category': category,
        'normalBalance': normalBalance,
      };
}

const List<ChartOfAccountItem> pfrsChartOfAccounts = [
  ChartOfAccountItem(
    code: '1010',
    name: 'Cash on Hand and in Banks',
    category: 'ASSET',
    normalBalance: 'DEBIT',
  ),
  ChartOfAccountItem(
    code: '1110',
    name: 'Accounts Receivable - Trade',
    category: 'ASSET',
    normalBalance: 'DEBIT',
  ),
  ChartOfAccountItem(
    code: '1150',
    name: 'Creditable Withholding Tax (BIR 2307)',
    category: 'ASSET',
    normalBalance: 'DEBIT',
  ),
  ChartOfAccountItem(
    code: '1160',
    name: 'Input VAT Receivable',
    category: 'ASSET',
    normalBalance: 'DEBIT',
  ),
  ChartOfAccountItem(
    code: '2010',
    name: 'Accounts Payable - Trade',
    category: 'LIABILITY',
    normalBalance: 'CREDIT',
  ),
  ChartOfAccountItem(
    code: '2110',
    name: 'Output VAT Payable',
    category: 'LIABILITY',
    normalBalance: 'CREDIT',
  ),
  ChartOfAccountItem(
    code: '2120',
    name: 'Expanded Withholding Tax Payable (1601-EQ)',
    category: 'LIABILITY',
    normalBalance: 'CREDIT',
  ),
  ChartOfAccountItem(
    code: '4010',
    name: 'Sales Revenue - Goods',
    category: 'REVENUE',
    normalBalance: 'CREDIT',
  ),
  ChartOfAccountItem(
    code: '4020',
    name: 'Service Revenue',
    category: 'REVENUE',
    normalBalance: 'CREDIT',
  ),
  ChartOfAccountItem(
    code: '4050',
    name: 'Sales Discounts (Regular / SC / PWD)',
    category: 'REVENUE',
    normalBalance: 'DEBIT',
  ),
  ChartOfAccountItem(
    code: '4060',
    name: 'Sales Returns & Allowances (Credit Memo)',
    category: 'REVENUE',
    normalBalance: 'DEBIT',
  ),
  ChartOfAccountItem(
    code: '5010',
    name: 'Purchases / Cost of Goods & Services',
    category: 'EXPENSE',
    normalBalance: 'DEBIT',
  ),
  ChartOfAccountItem(
    code: '6010',
    name: 'Operating & Professional Expenses',
    category: 'EXPENSE',
    normalBalance: 'DEBIT',
  ),
];

final Map<String, ChartOfAccountItem> _coaMap = {
  for (final a in pfrsChartOfAccounts) a.code: a,
};

class JournalLine {
  final String accountCode;
  final String accountName;
  final double debit;
  final double credit;

  const JournalLine({
    required this.accountCode,
    required this.accountName,
    required this.debit,
    required this.credit,
  });

  factory JournalLine.fromJson(Map<String, dynamic> json) => JournalLine(
        accountCode: json['accountCode']?.toString() ?? '',
        accountName: json['accountName']?.toString() ?? '',
        debit: (json['debit'] as num?)?.toDouble() ?? 0.0,
        credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'accountCode': accountCode,
        'accountName': accountName,
        'debit': debit,
        'credit': credit,
      };
}

class CasJournalEntry {
  final String id;
  final String taxpayerId;
  final String branchCd;
  final String bookType; // GJ | GL | SJ | PJ | CRJ | CDJ
  final String entryDate;
  final String referenceNo;
  final String eisUniqueId;
  final String counterpartyName;
  final String? counterpartyTin;
  final String particulars;
  final List<JournalLine> lines;
  final double totalDebit;
  final double totalCredit;
  final String createdAt;

  const CasJournalEntry({
    required this.id,
    required this.taxpayerId,
    required this.branchCd,
    required this.bookType,
    required this.entryDate,
    required this.referenceNo,
    required this.eisUniqueId,
    required this.counterpartyName,
    this.counterpartyTin,
    required this.particulars,
    required this.lines,
    required this.totalDebit,
    required this.totalCredit,
    required this.createdAt,
  });

  factory CasJournalEntry.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as List<dynamic>?) ?? const [];
    return CasJournalEntry(
      id: json['id']?.toString() ?? '',
      taxpayerId: json['taxpayerId']?.toString() ?? '',
      branchCd: json['branchCd']?.toString() ?? '0000',
      bookType: json['bookType']?.toString() ?? 'GJ',
      entryDate: json['entryDate']?.toString() ?? '',
      referenceNo: json['referenceNo']?.toString() ?? '',
      eisUniqueId: json['eisUniqueId']?.toString() ?? '',
      counterpartyName: json['counterpartyName']?.toString() ?? '',
      counterpartyTin: json['counterpartyTin']?.toString(),
      particulars: json['particulars']?.toString() ?? '',
      lines: rawLines
          .map((e) => JournalLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDebit: (json['totalDebit'] as num?)?.toDouble() ?? 0.0,
      totalCredit: (json['totalCredit'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'taxpayerId': taxpayerId,
        'branchCd': branchCd,
        'bookType': bookType,
        'entryDate': entryDate,
        'referenceNo': referenceNo,
        'eisUniqueId': eisUniqueId,
        'counterpartyName': counterpartyName,
        'counterpartyTin': counterpartyTin,
        'particulars': particulars,
        'lines': lines.map((l) => l.toJson()).toList(),
        'totalDebit': totalDebit,
        'totalCredit': totalCredit,
        'createdAt': createdAt,
      };
}

class TrialBalanceRow {
  final String accountCode;
  final String accountName;
  final String category;
  final double debitTotal;
  final double creditTotal;
  final double netBalance;

  const TrialBalanceRow({
    required this.accountCode,
    required this.accountName,
    required this.category,
    required this.debitTotal,
    required this.creditTotal,
    required this.netBalance,
  });

  Map<String, dynamic> toJson() => {
        'accountCode': accountCode,
        'accountName': accountName,
        'category': category,
        'debitTotal': debitTotal,
        'creditTotal': creditTotal,
        'netBalance': netBalance,
      };
}

JournalLine _line(String accountCode, double debit, double credit) {
  final acct = _coaMap[accountCode];
  return JournalLine(
    accountCode: accountCode,
    accountName: acct?.name ?? 'Account $accountCode',
    debit: round2(debit),
    credit: round2(credit),
  );
}

String _randomEntryId() {
  final rng = Random.secure();
  final hex = List.generate(
    4,
    (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join().toUpperCase();
  return 'JE-$hex';
}

CasJournalEntry _buildEntry({
  required String taxpayerId,
  required String branchCd,
  required String bookType,
  required String entryDate,
  required String referenceNo,
  required String eisUniqueId,
  required String counterpartyName,
  required String? counterpartyTin,
  required String particulars,
  required List<JournalLine> lines,
  required String createdAt,
}) {
  final filtered = lines.where((l) => l.debit != 0 || l.credit != 0).toList();
  final totalDebit = round2(filtered.fold(0.0, (acc, l) => acc + l.debit));
  final totalCredit = round2(filtered.fold(0.0, (acc, l) => acc + l.credit));
  return CasJournalEntry(
    id: _randomEntryId(),
    taxpayerId: taxpayerId,
    branchCd: branchCd,
    bookType: bookType,
    entryDate: entryDate,
    referenceNo: referenceNo,
    eisUniqueId: eisUniqueId,
    counterpartyName: counterpartyName,
    counterpartyTin: counterpartyTin,
    particulars: particulars,
    lines: filtered,
    totalDebit: totalDebit,
    totalCredit: totalCredit,
    createdAt: createdAt,
  );
}

List<CasJournalEntry> createJournalEntriesForInvoice(StoredInvoiceRecord record) {
  final p = record.payload;
  final s = p.summary;
  final entryDate = p.issueDtm.substring(0, 10);
  final nowIso = DateTime.now().toUtc().toIso8601String();
  final entries = <CasJournalEntry>[];

  if (record.direction == 'SALES') {
    final isCreditMemo = p.docType == '03';
    final revenueAcct = p.docType == '02' ? '4020' : '4010';
    final lines = <JournalLine>[];

    if (isCreditMemo) {
      if (s.netSales > 0) lines.add(_line('4060', s.netSales, 0));
      if (s.vatAmt > 0) lines.add(_line('2110', s.vatAmt, 0));
      if (s.withholdingTaxAmt > 0) {
        lines.add(_line('1150', 0, s.withholdingTaxAmt));
      }
      lines.add(_line(record.isPaid ? '1010' : '1110', 0, s.totalAmountDue));

      entries.add(
        _buildEntry(
          taxpayerId: record.taxpayerId,
          branchCd: record.branchCd,
          bookType: 'GJ',
          entryDate: entryDate,
          referenceNo: p.compInvoiceId,
          eisUniqueId: p.eisUniqueId,
          counterpartyName: p.buyer.regNm,
          counterpartyTin: p.buyer.tin,
          particulars:
              'Credit Memo (${p.refEisUniqueId ?? ''}) via ${record.sourceSystem}',
          lines: lines,
          createdAt: nowIso,
        ),
      );
      return entries;
    }

    lines.add(_line(record.isPaid ? '1010' : '1110', s.totalAmountDue, 0));
    if (s.withholdingTaxAmt > 0) {
      lines.add(_line('1150', s.withholdingTaxAmt, 0));
    }
    if (s.totalDiscountAmt > 0) {
      lines.add(_line('4050', s.totalDiscountAmt, 0));
    }
    if (s.grossSalesAmt + s.otherChargesAmt > 0) {
      lines.add(
        _line(revenueAcct, 0, round2(s.grossSalesAmt + s.otherChargesAmt)),
      );
    }
    if (s.vatAmt > 0) lines.add(_line('2110', 0, s.vatAmt));

    entries.add(
      _buildEntry(
        taxpayerId: record.taxpayerId,
        branchCd: record.branchCd,
        bookType: 'SJ',
        entryDate: entryDate,
        referenceNo: p.compInvoiceId,
        eisUniqueId: p.eisUniqueId,
        counterpartyName: p.buyer.regNm,
        counterpartyTin: p.buyer.tin,
        particulars:
            'BIR DocType ${p.docType} (${p.transClass}) via ${record.sourceSystem}',
        lines: lines,
        createdAt: nowIso,
      ),
    );

    if (record.isPaid && p.systemType == 'POS') {
      entries.add(
        _buildEntry(
          taxpayerId: record.taxpayerId,
          branchCd: record.branchCd,
          bookType: 'CRJ',
          entryDate: entryDate,
          referenceNo: 'OR-${p.compInvoiceId}',
          eisUniqueId: p.eisUniqueId,
          counterpartyName: p.buyer.regNm,
          counterpartyTin: p.buyer.tin,
          particulars: 'Cash Receipt for POS Invoice ${p.compInvoiceId}',
          lines: [
            _line('1010', s.totalAmountDue, 0),
            _line('1010', 0, s.totalAmountDue),
          ],
          createdAt: nowIso,
        ),
      );
    }

    return entries;
  }

  final lines = <JournalLine>[_line('5010', s.netSales, 0)];
  if (s.vatAmt > 0) lines.add(_line('1160', s.vatAmt, 0));
  if (s.withholdingTaxAmt > 0) {
    lines.add(_line('2120', 0, s.withholdingTaxAmt));
  }
  lines.add(_line(record.isPaid ? '1010' : '2010', 0, s.totalAmountDue));

  entries.add(
    _buildEntry(
      taxpayerId: record.taxpayerId,
      branchCd: record.branchCd,
      bookType: record.isPaid ? 'CDJ' : 'PJ',
      entryDate: entryDate,
      referenceNo: p.compInvoiceId,
      eisUniqueId: p.eisUniqueId,
      counterpartyName: p.seller.regNm,
      counterpartyTin: p.seller.tin,
      particulars: 'Purchase / Expense Bill via ${record.sourceSystem}',
      lines: lines,
      createdAt: nowIso,
    ),
  );

  return entries;
}

({
  List<TrialBalanceRow> rows,
  double totalDebits,
  double totalCredits,
  bool isBalanced,
}) computeTrialBalance(List<CasJournalEntry> entries) {
  final agg = <String, ({double debit, double credit})>{};

  for (final entry in entries) {
    for (final ln in entry.lines) {
      final cur = agg[ln.accountCode] ?? (debit: 0.0, credit: 0.0);
      agg[ln.accountCode] = (
        debit: round2(cur.debit + ln.debit),
        credit: round2(cur.credit + ln.credit),
      );
    }
  }

  final rows = <TrialBalanceRow>[];
  var totalDebits = 0.0;
  var totalCredits = 0.0;

  for (final acct in pfrsChartOfAccounts) {
    final val = agg[acct.code];
    if (val == null) continue;
    totalDebits = round2(totalDebits + val.debit);
    totalCredits = round2(totalCredits + val.credit);
    final netBalance = acct.normalBalance == 'DEBIT'
        ? round2(val.debit - val.credit)
        : round2(val.credit - val.debit);
    rows.add(
      TrialBalanceRow(
        accountCode: acct.code,
        accountName: acct.name,
        category: acct.category,
        debitTotal: val.debit,
        creditTotal: val.credit,
        netBalance: netBalance,
      ),
    );
  }

  return (
    rows: rows,
    totalDebits: totalDebits,
    totalCredits: totalCredits,
    isBalanced: (totalDebits - totalCredits).abs() <= 0.01,
  );
}
