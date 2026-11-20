// Gene - Nov, 20, 2026: Ported from eis_flutter UI domain models.
// Core domain models for the IES Philippine BIR EIS & CAS Flutter client.

class BirAddressModel {
  final String street;
  final String barangay;
  final String city;
  final String province;
  final String zipCode;

  const BirAddressModel({
    required this.street,
    required this.barangay,
    required this.city,
    required this.province,
    required this.zipCode,
  });

  factory BirAddressModel.fromJson(Map<String, dynamic> json) {
    return BirAddressModel(
      street: json['Street']?.toString() ?? '',
      barangay: json['Barangay']?.toString() ?? '',
      city: json['City']?.toString() ?? '',
      province: json['Province']?.toString() ?? '',
      zipCode: json['ZipCode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'Street': street,
        'Barangay': barangay,
        'City': city,
        'Province': province,
        'ZipCode': zipCode,
      };
}

class TaxpayerBranchModel {
  final String branchCd;
  final String branchName;
  final BirAddressModel address;
  final int lastSequence;
  final String invoicePrefix;

  const TaxpayerBranchModel({
    required this.branchCd,
    required this.branchName,
    required this.address,
    required this.lastSequence,
    required this.invoicePrefix,
  });

  factory TaxpayerBranchModel.fromJson(Map<String, dynamic> json) {
    return TaxpayerBranchModel(
      branchCd: json['branchCd']?.toString() ?? '0000',
      branchName: json['branchName']?.toString() ?? 'Head Office',
      address: BirAddressModel.fromJson(
        (json['address'] as Map<String, dynamic>?) ?? const {},
      ),
      lastSequence: (json['lastSequence'] as num?)?.toInt() ?? 0,
      invoicePrefix: json['invoicePrefix']?.toString() ?? 'SI-0000',
    );
  }
}

class TaxpayerProfileModel {
  final String id;
  final String workspaceId;
  final String tin;
  final String taxType;
  final String registeredName;
  final String businessName;
  final String email;
  final String eisCertId;
  final String pttNumber;
  final String keyId;
  final String publicKeyPem;
  final List<TaxpayerBranchModel> branches;

  const TaxpayerProfileModel({
    required this.id,
    required this.workspaceId,
    required this.tin,
    required this.taxType,
    required this.registeredName,
    required this.businessName,
    required this.email,
    required this.eisCertId,
    required this.pttNumber,
    required this.keyId,
    required this.publicKeyPem,
    required this.branches,
  });

  factory TaxpayerProfileModel.fromJson(Map<String, dynamic> json) {
    final rawBranches = (json['branches'] as List<dynamic>?) ?? const [];
    return TaxpayerProfileModel(
      id: json['id']?.toString() ?? '',
      workspaceId: json['workspaceId']?.toString() ?? '',
      tin: json['tin']?.toString() ?? '',
      taxType: json['taxType']?.toString() ?? 'VAT',
      registeredName: json['registeredName']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      eisCertId: json['eisCertId']?.toString() ?? '',
      pttNumber: json['pttNumber']?.toString() ?? '',
      keyId: json['keyId']?.toString() ?? '',
      publicKeyPem: json['publicKeyPem']?.toString() ?? '',
      branches: rawBranches
          .map((e) => TaxpayerBranchModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BirSummaryModel {
  final double grossSalesAmt;
  final double totalDiscountAmt;
  final double scPwdDiscountAmt;
  final double netSales;
  final double vatableSales;
  final double vatExemptSales;
  final double zeroRatedSales;
  final double vatAmt;
  final double withholdingTaxAmt;
  final double totalAmountDue;

  const BirSummaryModel({
    required this.grossSalesAmt,
    required this.totalDiscountAmt,
    required this.scPwdDiscountAmt,
    required this.netSales,
    required this.vatableSales,
    required this.vatExemptSales,
    required this.zeroRatedSales,
    required this.vatAmt,
    required this.withholdingTaxAmt,
    required this.totalAmountDue,
  });

  factory BirSummaryModel.fromJson(Map<String, dynamic> json) {
    double numVal(String k) => (json[k] as num?)?.toDouble() ?? 0.0;
    return BirSummaryModel(
      grossSalesAmt: numVal('GrossSalesAmt'),
      totalDiscountAmt: numVal('TotalDiscountAmt'),
      scPwdDiscountAmt: numVal('ScPwdDiscountAmt'),
      netSales: numVal('NetSales'),
      vatableSales: numVal('VATableSales'),
      vatExemptSales: numVal('VATExemptSales'),
      zeroRatedSales: numVal('ZeroRatedSales'),
      vatAmt: numVal('VATAmt'),
      withholdingTaxAmt: numVal('WithholdingTaxAmt'),
      totalAmountDue: numVal('TotalAmountDue'),
    );
  }
}

class StoredInvoiceModel {
  final String id;
  final String taxpayerId;
  final String branchCd;
  final String sourceSystem;
  final String direction;
  final String status;
  final int retryCount;
  final String threeDayDeadlineAt;
  final Map<String, dynamic> payload;
  final String jwsToken;
  final Map<String, dynamic> aesEnvelope;
  final Map<String, dynamic>? lastReceipt;
  final BirSummaryModel summary;

  const StoredInvoiceModel({
    required this.id,
    required this.taxpayerId,
    required this.branchCd,
    required this.sourceSystem,
    required this.direction,
    required this.status,
    required this.retryCount,
    required this.threeDayDeadlineAt,
    required this.payload,
    required this.jwsToken,
    required this.aesEnvelope,
    required this.lastReceipt,
    required this.summary,
  });

  String get eisUniqueId => payload['EisUniqueId']?.toString() ?? '';
  String get compInvoiceId => payload['CompInvoiceId']?.toString() ?? '';
  String get issueDtm => payload['IssueDtm']?.toString() ?? '';
  String get docType => payload['DocType']?.toString() ?? '01';
  String get transClass => payload['TransClass']?.toString() ?? 'B2B';
  String get buyerName =>
      (payload['Buyer'] as Map<String, dynamic>?)?['RegNm']?.toString() ?? '';
  String? get buyerTin =>
      (payload['Buyer'] as Map<String, dynamic>?)?['TIN']?.toString();
  String get ackCode => lastReceipt?['ackCode']?.toString() ?? status;
  String? get birAckId => lastReceipt?['birAckId']?.toString();

  factory StoredInvoiceModel.fromJson(Map<String, dynamic> json) {
    final payload = (json['payload'] as Map<String, dynamic>?) ?? const {};
    return StoredInvoiceModel(
      id: json['id']?.toString() ?? '',
      taxpayerId: json['taxpayerId']?.toString() ?? '',
      branchCd: json['branchCd']?.toString() ?? '0000',
      sourceSystem: json['sourceSystem']?.toString() ?? 'IES_UI',
      direction: json['direction']?.toString() ?? 'SALES',
      status: json['status']?.toString() ?? 'DRAFT',
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      threeDayDeadlineAt: json['threeDayDeadlineAt']?.toString() ?? '',
      payload: payload,
      jwsToken: json['jwsToken']?.toString() ?? '',
      aesEnvelope: (json['aesEnvelope'] as Map<String, dynamic>?) ?? const {},
      lastReceipt: json['lastReceipt'] as Map<String, dynamic>?,
      summary: BirSummaryModel.fromJson(
        (payload['Summary'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

class DashboardSummaryModel {
  final String gatewayMode;
  final bool simulateOutage;
  final int taxpayerCount;
  final int totalInvoices;
  final int transmittedCount;
  final int queuedRetryCount;
  final int rejectedCount;
  final double totalSalesPhp;
  final double totalOutputVatPhp;
  final double totalCwtPhp;
  final Map<String, int> bySource;
  final bool auditChainValid;
  final int auditTotalEntries;

  const DashboardSummaryModel({
    required this.gatewayMode,
    required this.simulateOutage,
    required this.taxpayerCount,
    required this.totalInvoices,
    required this.transmittedCount,
    required this.queuedRetryCount,
    required this.rejectedCount,
    required this.totalSalesPhp,
    required this.totalOutputVatPhp,
    required this.totalCwtPhp,
    required this.bySource,
    required this.auditChainValid,
    required this.auditTotalEntries,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    final gw = (json['gatewayConfig'] as Map<String, dynamic>?) ?? const {};
    final counts = (json['invoiceCounts'] as Map<String, dynamic>?) ?? const {};
    final fin = (json['financialsPhp'] as Map<String, dynamic>?) ?? const {};
    final audit = (json['auditChain'] as Map<String, dynamic>?) ?? const {};
    final srcRaw = (json['bySource'] as Map<String, dynamic>?) ?? const {};

    return DashboardSummaryModel(
      gatewayMode: gw['mode']?.toString() ?? 'MOCK_BIR_SIMULATOR',
      simulateOutage: gw['simulateOutage'] == true,
      taxpayerCount: (json['taxpayerCount'] as num?)?.toInt() ?? 0,
      totalInvoices: (counts['total'] as num?)?.toInt() ?? 0,
      transmittedCount: (counts['transmitted'] as num?)?.toInt() ?? 0,
      queuedRetryCount: (counts['queuedRetry'] as num?)?.toInt() ?? 0,
      rejectedCount: (counts['rejected'] as num?)?.toInt() ?? 0,
      totalSalesPhp: (fin['totalSales'] as num?)?.toDouble() ?? 0.0,
      totalOutputVatPhp: (fin['totalOutputVat'] as num?)?.toDouble() ?? 0.0,
      totalCwtPhp: (fin['totalCwt'] as num?)?.toDouble() ?? 0.0,
      bySource: srcRaw.map((k, v) => MapEntry(k, (v as num).toInt())),
      auditChainValid: audit['valid'] == true,
      auditTotalEntries: (audit['totalEntries'] as num?)?.toInt() ?? 0,
    );
  }
}

class JournalLineModel {
  final String accountCode;
  final String accountName;
  final double debit;
  final double credit;

  const JournalLineModel({
    required this.accountCode,
    required this.accountName,
    required this.debit,
    required this.credit,
  });

  factory JournalLineModel.fromJson(Map<String, dynamic> json) {
    return JournalLineModel(
      accountCode: json['accountCode']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      debit: (json['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CasJournalEntryModel {
  final String id;
  final String bookType;
  final String entryDate;
  final String referenceNo;
  final String eisUniqueId;
  final String counterpartyName;
  final String particulars;
  final List<JournalLineModel> lines;
  final double totalDebit;
  final double totalCredit;

  const CasJournalEntryModel({
    required this.id,
    required this.bookType,
    required this.entryDate,
    required this.referenceNo,
    required this.eisUniqueId,
    required this.counterpartyName,
    required this.particulars,
    required this.lines,
    required this.totalDebit,
    required this.totalCredit,
  });

  factory CasJournalEntryModel.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['lines'] as List<dynamic>?) ?? const [];
    return CasJournalEntryModel(
      id: json['id']?.toString() ?? '',
      bookType: json['bookType']?.toString() ?? 'GJ',
      entryDate: json['entryDate']?.toString() ?? '',
      referenceNo: json['referenceNo']?.toString() ?? '',
      eisUniqueId: json['eisUniqueId']?.toString() ?? '',
      counterpartyName: json['counterpartyName']?.toString() ?? '',
      particulars: json['particulars']?.toString() ?? '',
      lines: rawLines
          .map((e) => JournalLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDebit: (json['totalDebit'] as num?)?.toDouble() ?? 0.0,
      totalCredit: (json['totalCredit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TrialBalanceRowModel {
  final String accountCode;
  final String accountName;
  final String category;
  final double debitTotal;
  final double creditTotal;
  final double netBalance;

  const TrialBalanceRowModel({
    required this.accountCode,
    required this.accountName,
    required this.category,
    required this.debitTotal,
    required this.creditTotal,
    required this.netBalance,
  });

  factory TrialBalanceRowModel.fromJson(Map<String, dynamic> json) {
    return TrialBalanceRowModel(
      accountCode: json['accountCode']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      debitTotal: (json['debitTotal'] as num?)?.toDouble() ?? 0.0,
      creditTotal: (json['creditTotal'] as num?)?.toDouble() ?? 0.0,
      netBalance: (json['netBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CasBooksDataModel {
  final List<CasJournalEntryModel> entries;
  final List<TrialBalanceRowModel> trialBalanceRows;
  final double totalDebits;
  final double totalCredits;
  final bool isBalanced;

  const CasBooksDataModel({
    required this.entries,
    required this.trialBalanceRows,
    required this.totalDebits,
    required this.totalCredits,
    required this.isBalanced,
  });

  factory CasBooksDataModel.fromJson(Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List<dynamic>?) ?? const [];
    final tb = (json['trialBalance'] as Map<String, dynamic>?) ?? const {};
    final rawRows = (tb['rows'] as List<dynamic>?) ?? const [];
    return CasBooksDataModel(
      entries: rawEntries
          .map((e) => CasJournalEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      trialBalanceRows: rawRows
          .map((e) => TrialBalanceRowModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDebits: (tb['totalDebits'] as num?)?.toDouble() ?? 0.0,
      totalCredits: (tb['totalCredits'] as num?)?.toDouble() ?? 0.0,
      isBalanced: tb['isBalanced'] == true,
    );
  }
}

class StatutoryReportModel {
  final String filename;
  final String datContent;
  final String csvContent;
  final int rowCount;

  const StatutoryReportModel({
    required this.filename,
    required this.datContent,
    required this.csvContent,
    required this.rowCount,
  });

  factory StatutoryReportModel.fromJson(Map<String, dynamic> json) {
    return StatutoryReportModel(
      filename: json['filename']?.toString() ?? '',
      datContent: json['datContent']?.toString() ?? '',
      csvContent: json['csvContent']?.toString() ?? '',
      rowCount: (json['rowCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AuditTrailEntryModel {
  final int seq;
  final String id;
  final String timestamp;
  final String actor;
  final String action;
  final String taxpayerTin;
  final String entityId;
  final String details;
  final String prevHash;
  final String entryHash;

  const AuditTrailEntryModel({
    required this.seq,
    required this.id,
    required this.timestamp,
    required this.actor,
    required this.action,
    required this.taxpayerTin,
    required this.entityId,
    required this.details,
    required this.prevHash,
    required this.entryHash,
  });

  factory AuditTrailEntryModel.fromJson(Map<String, dynamic> json) {
    return AuditTrailEntryModel(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      id: json['id']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      actor: json['actor']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      taxpayerTin: json['taxpayerTin']?.toString() ?? '',
      entityId: json['entityId']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      prevHash: json['prevHash']?.toString() ?? '',
      entryHash: json['entryHash']?.toString() ?? '',
    );
  }
}

class AuditTrailResponseModel {
  final bool valid;
  final int totalEntries;
  final int? brokenAtSeq;
  final List<AuditTrailEntryModel> entries;

  const AuditTrailResponseModel({
    required this.valid,
    required this.totalEntries,
    required this.brokenAtSeq,
    required this.entries,
  });

  factory AuditTrailResponseModel.fromJson(Map<String, dynamic> json) {
    final ver = (json['verification'] as Map<String, dynamic>?) ?? const {};
    final raw = (json['entries'] as List<dynamic>?) ?? const [];
    return AuditTrailResponseModel(
      valid: ver['valid'] == true,
      totalEntries: (ver['totalEntries'] as num?)?.toInt() ?? 0,
      brokenAtSeq: (ver['brokenAtSeq'] as num?)?.toInt(),
      entries: raw
          .map((e) => AuditTrailEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Offline / Client-side EOPT RR 7-2024 live calculation preview helper.
class EoptPreviewCalculator {
  static Map<String, double> compute({
    required double qty,
    required double unitPrice,
    required bool priceIncludesVat,
    required String taxClassification,
    required String buyerCategory,
    required String? atcCode,
  }) {
    final isScPwd = buyerCategory == 'SENIOR_CITIZEN' || buyerCategory == 'PWD';
    final effectiveClass = isScPwd ? 'VAT_EXEMPT' : taxClassification;
    final baseUnit = priceIncludesVat && taxClassification == 'VATABLE'
        ? unitPrice / 1.12
        : unitPrice;
    final gross = qty * baseUnit;
    final discount = isScPwd ? gross * 0.20 : 0.0;
    final netSales = (gross - discount).clamp(0.0, double.infinity);
    final vat = effectiveClass == 'VATABLE' ? netSales * 0.12 : 0.0;
    final cwtRate = switch (atcCode) {
      'WI010' => 0.05,
      'WC010' => 0.10,
      'WI158' || 'WC158' => 0.01,
      'WI160' || 'WC160' => 0.02,
      'WC100' => 0.05,
      _ => 0.0,
    };
    final cwt = netSales * cwtRate;
    final totalDue = netSales + vat - cwt;

    return {
      'gross': gross,
      'discount': discount,
      'netSales': netSales,
      'vat': vat,
      'cwt': cwt,
      'totalDue': totalDue,
    };
  }
}
