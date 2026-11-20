// BIR Electronic Invoicing System (EIS) JSON Schema v2.01 & Canonical Tax Domain Types
// Aligned with:
//  - BIR EIS JSON Technical Specification v2.01 (CAS & CRM/POS variants)
//  - RA 11976 (Ease of Paying Taxes / EOPT Act) & RR No. 7-2024
//  - RR No. 11-2025 & RR No. 26-2025 (EIS Mandatory Transmission)
//  - RR No. 6-2026 (Creditable Withholding Tax / CWT)

class BirAddress {
  final String street;
  final String barangay;
  final String city;
  final String province;
  final String zipCode;

  const BirAddress({
    required this.street,
    required this.barangay,
    required this.city,
    required this.province,
    required this.zipCode,
  });

  factory BirAddress.fromJson(Map<String, dynamic> json) => BirAddress(
        street: json['Street']?.toString() ?? '',
        barangay: json['Barangay']?.toString() ?? '',
        city: json['City']?.toString() ?? '',
        province: json['Province']?.toString() ?? '',
        zipCode: json['ZipCode']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'Street': street,
        'Barangay': barangay,
        'City': city,
        'Province': province,
        'ZipCode': zipCode,
      };
}

class SellerInfo {
  final String tin; // 9 digits
  final String branchCd; // 4 digits, e.g. "0000"
  final String type; // "VAT" | "NON_VAT"
  final String regNm;
  final String businessNm;
  final BirAddress address;
  final String email;

  const SellerInfo({
    required this.tin,
    required this.branchCd,
    required this.type,
    required this.regNm,
    required this.businessNm,
    required this.address,
    required this.email,
  });

  factory SellerInfo.fromJson(Map<String, dynamic> json) => SellerInfo(
        tin: json['TIN']?.toString() ?? '',
        branchCd: json['BranchCd']?.toString() ?? '0000',
        type: json['Type']?.toString() ?? 'VAT',
        regNm: json['RegNm']?.toString() ?? '',
        businessNm: json['BusinessNm']?.toString() ?? '',
        address: BirAddress.fromJson(
          (json['Address'] as Map<String, dynamic>?) ?? const {},
        ),
        email: json['Email']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'TIN': tin,
        'BranchCd': branchCd,
        'Type': type,
        'RegNm': regNm,
        'BusinessNm': businessNm,
        'Address': address.toJson(),
        'Email': email,
      };
}

class BuyerInfo {
  final String? tin;
  final String? branchCd;
  final String regNm;
  final BirAddress? address;
  final String buyerCategory; // REGULAR | SENIOR_CITIZEN | PWD | NAAC | SOLO_PARENT | DIPLOMAT
  final String? osacaPwdId;

  const BuyerInfo({
    required this.tin,
    required this.branchCd,
    required this.regNm,
    required this.address,
    required this.buyerCategory,
    this.osacaPwdId,
  });

  factory BuyerInfo.fromJson(Map<String, dynamic> json) => BuyerInfo(
        tin: json['TIN']?.toString(),
        branchCd: json['BranchCd']?.toString(),
        regNm: json['RegNm']?.toString() ?? '',
        address: json['Address'] is Map<String, dynamic>
            ? BirAddress.fromJson(json['Address'] as Map<String, dynamic>)
            : null,
        buyerCategory: json['BuyerCategory']?.toString() ?? 'REGULAR',
        osacaPwdId: json['OsacaPwdId']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'TIN': tin,
        'BranchCd': branchCd,
        'RegNm': regNm,
        'Address': address?.toJson(),
        'BuyerCategory': buyerCategory,
        'OsacaPwdId': osacaPwdId,
      };
}

class BirEisItem {
  final int lineNo;
  final String itemCd;
  final String itemNm;
  final String unit;
  final double qty;
  final double unitCost;
  final double grossAmt;
  final String discountType;
  final double discountAmt;
  final double netSales;
  final String taxClassification; // VATABLE | VAT_EXEMPT | ZERO_RATED
  final double vatAmt;
  final String? atcCode;
  final double cwtRate;
  final double cwtAmt;

  const BirEisItem({
    required this.lineNo,
    required this.itemCd,
    required this.itemNm,
    required this.unit,
    required this.qty,
    required this.unitCost,
    required this.grossAmt,
    required this.discountType,
    required this.discountAmt,
    required this.netSales,
    required this.taxClassification,
    required this.vatAmt,
    required this.atcCode,
    required this.cwtRate,
    required this.cwtAmt,
  });

  factory BirEisItem.fromJson(Map<String, dynamic> json) => BirEisItem(
        lineNo: (json['LineNo'] as num?)?.toInt() ?? 1,
        itemCd: json['ItemCd']?.toString() ?? '',
        itemNm: json['ItemNm']?.toString() ?? '',
        unit: json['Unit']?.toString() ?? 'PCS',
        qty: (json['Qty'] as num?)?.toDouble() ?? 0.0,
        unitCost: (json['UnitCost'] as num?)?.toDouble() ?? 0.0,
        grossAmt: (json['GrossAmt'] as num?)?.toDouble() ?? 0.0,
        discountType: json['DiscountType']?.toString() ?? 'NONE',
        discountAmt: (json['DiscountAmt'] as num?)?.toDouble() ?? 0.0,
        netSales: (json['NetSales'] as num?)?.toDouble() ?? 0.0,
        taxClassification: json['TaxClassification']?.toString() ?? 'VATABLE',
        vatAmt: (json['VATAmt'] as num?)?.toDouble() ?? 0.0,
        atcCode: json['AtcCode']?.toString(),
        cwtRate: (json['CwtRate'] as num?)?.toDouble() ?? 0.0,
        cwtAmt: (json['CwtAmt'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'LineNo': lineNo,
        'ItemCd': itemCd,
        'ItemNm': itemNm,
        'Unit': unit,
        'Qty': qty,
        'UnitCost': unitCost,
        'GrossAmt': grossAmt,
        'DiscountType': discountType,
        'DiscountAmt': discountAmt,
        'NetSales': netSales,
        'TaxClassification': taxClassification,
        'VATAmt': vatAmt,
        'AtcCode': atcCode,
        'CwtRate': cwtRate,
        'CwtAmt': cwtAmt,
      };
}

class BirEisSummary {
  final double grossSalesAmt;
  final double totalDiscountAmt;
  final double scPwdDiscountAmt;
  final double netSales;
  final double vatableSales;
  final double vatExemptSales;
  final double zeroRatedSales;
  final double vatAmt;
  final double withholdingTaxAmt;
  final double otherChargesAmt;
  final double totalAmountDue;

  const BirEisSummary({
    required this.grossSalesAmt,
    required this.totalDiscountAmt,
    required this.scPwdDiscountAmt,
    required this.netSales,
    required this.vatableSales,
    required this.vatExemptSales,
    required this.zeroRatedSales,
    required this.vatAmt,
    required this.withholdingTaxAmt,
    required this.otherChargesAmt,
    required this.totalAmountDue,
  });

  factory BirEisSummary.fromJson(Map<String, dynamic> json) {
    double n(String k) => (json[k] as num?)?.toDouble() ?? 0.0;
    return BirEisSummary(
      grossSalesAmt: n('GrossSalesAmt'),
      totalDiscountAmt: n('TotalDiscountAmt'),
      scPwdDiscountAmt: n('ScPwdDiscountAmt'),
      netSales: n('NetSales'),
      vatableSales: n('VATableSales'),
      vatExemptSales: n('VATExemptSales'),
      zeroRatedSales: n('ZeroRatedSales'),
      vatAmt: n('VATAmt'),
      withholdingTaxAmt: n('WithholdingTaxAmt'),
      otherChargesAmt: n('OtherChargesAmt'),
      totalAmountDue: n('TotalAmountDue'),
    );
  }

  Map<String, dynamic> toJson() => {
        'GrossSalesAmt': grossSalesAmt,
        'TotalDiscountAmt': totalDiscountAmt,
        'ScPwdDiscountAmt': scPwdDiscountAmt,
        'NetSales': netSales,
        'VATableSales': vatableSales,
        'VATExemptSales': vatExemptSales,
        'ZeroRatedSales': zeroRatedSales,
        'VATAmt': vatAmt,
        'WithholdingTaxAmt': withholdingTaxAmt,
        'OtherChargesAmt': otherChargesAmt,
        'TotalAmountDue': totalAmountDue,
      };
}

class BirEisPayloadV201 {
  final String schemaVer; // "v2.01"
  final String systemType; // "CAS" | "POS"
  final String eisUniqueId; // 24 chars
  final String compInvoiceId;
  final String issueDtm; // YYYY-MM-DDTHH:mm:ss
  final String docType; // "01" | "02" | "03" | "04"
  final String transClass; // "B2B" | "B2C" | "EXPORT" | "GOVT"
  final String corrYN; // "Y" | "N"
  final String? refEisUniqueId;
  final String currency; // "PHP"
  final SellerInfo seller;
  final BuyerInfo buyer;
  final List<BirEisItem> itemList;
  final BirEisSummary summary;

  const BirEisPayloadV201({
    this.schemaVer = 'v2.01',
    required this.systemType,
    required this.eisUniqueId,
    required this.compInvoiceId,
    required this.issueDtm,
    required this.docType,
    required this.transClass,
    required this.corrYN,
    this.refEisUniqueId,
    this.currency = 'PHP',
    required this.seller,
    required this.buyer,
    required this.itemList,
    required this.summary,
  });

  factory BirEisPayloadV201.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['ItemList'] as List<dynamic>?) ?? const [];
    return BirEisPayloadV201(
      schemaVer: json['SchemaVer']?.toString() ?? 'v2.01',
      systemType: json['SystemType']?.toString() ?? 'CAS',
      eisUniqueId: json['EisUniqueId']?.toString() ?? '',
      compInvoiceId: json['CompInvoiceId']?.toString() ?? '',
      issueDtm: json['IssueDtm']?.toString() ?? '',
      docType: json['DocType']?.toString() ?? '01',
      transClass: json['TransClass']?.toString() ?? 'B2B',
      corrYN: json['CorrYN']?.toString() ?? 'N',
      refEisUniqueId: json['RefEisUniqueId']?.toString(),
      currency: json['Currency']?.toString() ?? 'PHP',
      seller: SellerInfo.fromJson(
        (json['Seller'] as Map<String, dynamic>?) ?? const {},
      ),
      buyer: BuyerInfo.fromJson(
        (json['Buyer'] as Map<String, dynamic>?) ?? const {},
      ),
      itemList: rawItems
          .map((e) => BirEisItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: BirEisSummary.fromJson(
        (json['Summary'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'SchemaVer': schemaVer,
        'SystemType': systemType,
        'EisUniqueId': eisUniqueId,
        'CompInvoiceId': compInvoiceId,
        'IssueDtm': issueDtm,
        'DocType': docType,
        'TransClass': transClass,
        'CorrYN': corrYN,
        'RefEisUniqueId': refEisUniqueId,
        'Currency': currency,
        'Seller': seller.toJson(),
        'Buyer': buyer.toJson(),
        'ItemList': itemList.map((e) => e.toJson()).toList(),
        'Summary': summary.toJson(),
      };
}

class TaxpayerBranch {
  final String branchCd;
  final String branchName;
  final BirAddress address;
  int lastSequence;
  final String invoicePrefix;

  TaxpayerBranch({
    required this.branchCd,
    required this.branchName,
    required this.address,
    this.lastSequence = 0,
    required this.invoicePrefix,
  });

  factory TaxpayerBranch.fromJson(Map<String, dynamic> json) => TaxpayerBranch(
        branchCd: json['branchCd']?.toString() ?? '0000',
        branchName: json['branchName']?.toString() ?? 'Head Office',
        address: BirAddress.fromJson(
          (json['address'] as Map<String, dynamic>?) ?? const {},
        ),
        lastSequence: (json['lastSequence'] as num?)?.toInt() ?? 0,
        invoicePrefix: json['invoicePrefix']?.toString() ?? 'SI-0000',
      );

  Map<String, dynamic> toJson() => {
        'branchCd': branchCd,
        'branchName': branchName,
        'address': address.toJson(),
        'lastSequence': lastSequence,
        'invoicePrefix': invoicePrefix,
      };
}

class TaxpayerProfile {
  final String id;
  final String workspaceId;
  final String tin;
  final String taxType; // VAT | NON_VAT
  final String registeredName;
  final String businessName;
  final String email;
  final String eisCertId;
  final String pttNumber;
  String publicKeyJson;
  String privateKeyJson;
  String aesKeyHex;
  String keyId;
  // Gene - Nov, 20, 2026: Added taxpayer-level lastEisSequence so EisUniqueId never collides across branches sharing an EisCertId.
  int lastEisSequence;
  final List<TaxpayerBranch> branches;
  final String createdAt;

  TaxpayerProfile({
    required this.id,
    required this.workspaceId,
    required this.tin,
    required this.taxType,
    required this.registeredName,
    required this.businessName,
    required this.email,
    required this.eisCertId,
    required this.pttNumber,
    required this.publicKeyJson,
    required this.privateKeyJson,
    required this.aesKeyHex,
    required this.keyId,
    this.lastEisSequence = 0,
    required this.branches,
    required this.createdAt,
  });

  factory TaxpayerProfile.fromJson(Map<String, dynamic> json) {
    final rawBranches = (json['branches'] as List<dynamic>?) ?? const [];
    final parsedBranches = rawBranches
        .map((e) => TaxpayerBranch.fromJson(e as Map<String, dynamic>))
        .toList();
    final fallbackEisSeq = parsedBranches.fold<int>(
      0,
      (sum, b) => sum + b.lastSequence,
    );
    return TaxpayerProfile(
      id: json['id']?.toString() ?? '',
      workspaceId: json['workspaceId']?.toString() ?? 'WS-PH-DEFAULT',
      tin: json['tin']?.toString() ?? '',
      taxType: json['taxType']?.toString() ?? 'VAT',
      registeredName: json['registeredName']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      eisCertId: json['eisCertId']?.toString() ?? '',
      pttNumber: json['pttNumber']?.toString() ?? '',
      publicKeyJson: json['publicKeyJson']?.toString() ?? '',
      privateKeyJson: json['privateKeyJson']?.toString() ?? '',
      aesKeyHex: json['aesKeyHex']?.toString() ?? '',
      keyId: json['keyId']?.toString() ?? '',
      lastEisSequence:
          (json['lastEisSequence'] as num?)?.toInt() ?? fallbackEisSeq,
      branches: parsedBranches,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson({bool includePrivate = true}) => {
        'id': id,
        'workspaceId': workspaceId,
        'tin': tin,
        'taxType': taxType,
        'registeredName': registeredName,
        'businessName': businessName,
        'email': email,
        'eisCertId': eisCertId,
        'pttNumber': pttNumber,
        'keyId': keyId,
        'lastEisSequence': lastEisSequence,
        'publicKeyPem': publicKeyJson,
        if (includePrivate) 'publicKeyJson': publicKeyJson,
        if (includePrivate) 'privateKeyJson': privateKeyJson,
        if (includePrivate) 'aesKeyHex': aesKeyHex,
        'branches': branches.map((b) => b.toJson()).toList(),
        'createdAt': createdAt,
      };
}

class BirGatewayReceipt {
  final String ackCode; // ACK-200 | SYN004 | VAL001 | DUP001 | SEC001 | NET503
  final bool accepted;
  final String? birAckId;
  final String message;
  final List<String> errors;
  final String gatewayTier;
  final String processedAt;
  final String jwsThumbprint;

  const BirGatewayReceipt({
    required this.ackCode,
    required this.accepted,
    required this.birAckId,
    required this.message,
    required this.errors,
    required this.gatewayTier,
    required this.processedAt,
    required this.jwsThumbprint,
  });

  factory BirGatewayReceipt.fromJson(Map<String, dynamic> json) =>
      BirGatewayReceipt(
        ackCode: json['ackCode']?.toString() ?? 'ACK-200',
        accepted: json['accepted'] == true,
        birAckId: json['birAckId']?.toString(),
        message: json['message']?.toString() ?? '',
        errors: ((json['errors'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        gatewayTier: json['gatewayTier']?.toString() ?? 'MOCK_BIR_SIMULATOR',
        processedAt: json['processedAt']?.toString() ?? '',
        jwsThumbprint: json['jwsThumbprint']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'ackCode': ackCode,
        'accepted': accepted,
        'birAckId': birAckId,
        'message': message,
        'errors': errors,
        'gatewayTier': gatewayTier,
        'processedAt': processedAt,
        'jwsThumbprint': jwsThumbprint,
      };
}

class AesGcmEnvelope {
  final String algorithm;
  final String ivHex;
  final String authTagHex;
  final String ciphertextBase64;
  final String sha256Digest;

  const AesGcmEnvelope({
    this.algorithm = 'AES-256-GCM',
    required this.ivHex,
    required this.authTagHex,
    required this.ciphertextBase64,
    required this.sha256Digest,
  });

  factory AesGcmEnvelope.fromJson(Map<String, dynamic> json) => AesGcmEnvelope(
        algorithm: json['algorithm']?.toString() ?? 'AES-256-GCM',
        ivHex: json['ivHex']?.toString() ?? '',
        authTagHex: json['authTagHex']?.toString() ?? '',
        ciphertextBase64: json['ciphertextBase64']?.toString() ?? '',
        sha256Digest: json['sha256Digest']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'algorithm': algorithm,
        'ivHex': ivHex,
        'authTagHex': authTagHex,
        'ciphertextBase64': ciphertextBase64,
        'sha256Digest': sha256Digest,
      };
}

class StoredInvoiceRecord {
  final String id;
  final String taxpayerId;
  final String branchCd;
  final String sourceSystem;
  final String? externalRefId;
  final String direction; // SALES | PURCHASE
  final bool isPaid;
  final BirEisPayloadV201 payload;
  final String jwsToken;
  final AesGcmEnvelope aesEnvelope;
  String status; // DRAFT | QUEUED_RETRY | TRANSMITTED | REJECTED
  int retryCount;
  String? nextRetryAt;
  final String threeDayDeadlineAt;
  BirGatewayReceipt? lastReceipt;
  final String createdAt;

  StoredInvoiceRecord({
    required this.id,
    required this.taxpayerId,
    required this.branchCd,
    required this.sourceSystem,
    this.externalRefId,
    required this.direction,
    required this.isPaid,
    required this.payload,
    required this.jwsToken,
    required this.aesEnvelope,
    required this.status,
    required this.retryCount,
    this.nextRetryAt,
    required this.threeDayDeadlineAt,
    this.lastReceipt,
    required this.createdAt,
  });

  factory StoredInvoiceRecord.fromJson(Map<String, dynamic> json) =>
      StoredInvoiceRecord(
        id: json['id']?.toString() ?? '',
        taxpayerId: json['taxpayerId']?.toString() ?? '',
        branchCd: json['branchCd']?.toString() ?? '0000',
        sourceSystem: json['sourceSystem']?.toString() ?? 'IES_UI',
        externalRefId: json['externalRefId']?.toString(),
        direction: json['direction']?.toString() ?? 'SALES',
        isPaid: json['isPaid'] == true,
        payload: BirEisPayloadV201.fromJson(
          (json['payload'] as Map<String, dynamic>?) ?? const {},
        ),
        jwsToken: json['jwsToken']?.toString() ?? '',
        aesEnvelope: AesGcmEnvelope.fromJson(
          (json['aesEnvelope'] as Map<String, dynamic>?) ?? const {},
        ),
        status: json['status']?.toString() ?? 'DRAFT',
        retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
        nextRetryAt: json['nextRetryAt']?.toString(),
        threeDayDeadlineAt: json['threeDayDeadlineAt']?.toString() ?? '',
        lastReceipt: json['lastReceipt'] is Map<String, dynamic>
            ? BirGatewayReceipt.fromJson(
                json['lastReceipt'] as Map<String, dynamic>,
              )
            : null,
        createdAt: json['createdAt']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'taxpayerId': taxpayerId,
        'branchCd': branchCd,
        'sourceSystem': sourceSystem,
        'externalRefId': externalRefId,
        'direction': direction,
        'isPaid': isPaid,
        'payload': payload.toJson(),
        'jwsToken': jwsToken,
        'aesEnvelope': aesEnvelope.toJson(),
        'status': status,
        'retryCount': retryCount,
        'nextRetryAt': nextRetryAt,
        'threeDayDeadlineAt': threeDayDeadlineAt,
        'lastReceipt': lastReceipt?.toJson(),
        'createdAt': createdAt,
      };
}

String normalizeTin9(String rawTin) {
  final digits = rawTin.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 9) {
    return digits.substring(0, 9);
  }
  return digits.padLeft(9, '0');
}

String normalizeBranchCd(String? rawBranch) {
  final digits = (rawBranch ?? '0000').replaceAll(RegExp(r'\D'), '');
  final clipped = digits.length > 4 ? digits.substring(0, 4) : digits;
  return clipped.padLeft(4, '0');
}

/// Generates the mandatory 24-character BIR EIS EisUniqueId:
/// YYYYMMDD (8) + EisCertId (8) + Zero-padded Sequential Control (8)
String buildEisUniqueId(
  DateTime issueDate,
  String eisCertId,
  int sequenceNumber,
) {
  final yyyy = issueDate.year.toString();
  final mm = issueDate.month.toString().padLeft(2, '0');
  final dd = issueDate.day.toString().padLeft(2, '0');
  final cert = eisCertId
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toUpperCase()
      .padRight(8, '0')
      .substring(0, 8);
  final seqRaw = sequenceNumber.toString().padLeft(8, '0');
  final seq = seqRaw.substring(seqRaw.length - 8);
  return '$yyyy$mm$dd$cert$seq';
}

String formatBirDateTime(DateTime date) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${p(date.month)}-${p(date.day)}T'
      '${p(date.hour)}:${p(date.minute)}:${p(date.second)}';
}

List<String> validateBirSchemaV201(BirEisPayloadV201 payload) {
  final errors = <String>[];

  if (payload.schemaVer != 'v2.01') {
    errors.add('SYN004: SchemaVer must be "v2.01".');
  }
  if (!RegExp(r'^\d{8}[A-Z0-9]{8}\d{8}$').hasMatch(payload.eisUniqueId) ||
      payload.eisUniqueId.length != 24) {
    errors.add(
      'SYN004: EisUniqueId "${payload.eisUniqueId}" must be 24 characters (YYYYMMDD + 8-char CertId + 8-digit Seq).',
    );
  }
  if (payload.compInvoiceId.trim().isEmpty) {
    errors.add('SYN004: CompInvoiceId is mandatory.');
  }
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$')
      .hasMatch(payload.issueDtm)) {
    errors.add('SYN004: IssueDtm must follow YYYY-MM-DDTHH:mm:ss format.');
  }
  if (payload.currency != 'PHP') {
    errors.add('SYN004: Currency must be PHP for BIR EIS.');
  }
  if (!RegExp(r'^\d{9}$').hasMatch(payload.seller.tin)) {
    errors.add('SYN004: Seller.TIN must be exactly 9 numeric digits.');
  }
  if (!RegExp(r'^\d{4}$').hasMatch(payload.seller.branchCd)) {
    errors.add('SYN004: Seller.BranchCd must be 4 numeric digits.');
  }
  if (payload.seller.regNm.trim().isEmpty) {
    errors.add('SYN004: Seller.RegNm is mandatory.');
  }
  if (payload.transClass == 'B2B' &&
      (payload.buyer.tin == null ||
          !RegExp(r'^\d{9}$').hasMatch(payload.buyer.tin!))) {
    errors.add(
      'SYN004: Buyer.TIN (9 digits) is mandatory for B2B transactions under RR 7-2024.',
    );
  }
  if (payload.buyer.regNm.trim().isEmpty) {
    errors.add('SYN004: Buyer.RegNm is mandatory.');
  }
  if (payload.corrYN == 'Y' &&
      (payload.refEisUniqueId == null || payload.refEisUniqueId!.isEmpty)) {
    errors.add(
      'SYN004: RefEisUniqueId is required when CorrYN is "Y" (Credit/Debit Memo).',
    );
  }
  if (payload.itemList.isEmpty) {
    errors.add('SYN004: ItemList must contain at least one line item.');
  }
  for (final item in payload.itemList) {
    if (item.itemNm.trim().isEmpty) {
      errors.add('SYN004: ItemList[${item.lineNo}].ItemNm is mandatory.');
    }
    if (item.qty <= 0) {
      errors.add('SYN004: ItemList[${item.lineNo}].Qty must be greater than 0.');
    }
  }

  return errors;
}
