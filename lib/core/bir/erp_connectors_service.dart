// Gene - Nov, 20, 2026: Ported from eis pure-Dart BIR EIS/CAS engine.
import 'bir_eis_schema.dart';
import 'tax_calculator_service.dart';

class CanonicalIngestInput {
  final String? taxpayerId;
  final String? branchCd;
  final String sourceSystem;
  final String? externalRefId;
  final String? compInvoiceId;
  final String systemType;
  final String docType;
  final String? transClass;
  final String direction; // SALES | PURCHASE
  final bool isPaid;
  final String? issueDtm;
  final String? corrYN;
  final String? refEisUniqueId;
  final String buyerName;
  final String? buyerTin;
  final String? buyerBranchCd;
  final String buyerCategory;
  final String? osacaPwdId;
  final BirAddress? buyerAddress;
  final List<RawLineItemInput> items;
  final double otherChargesAmt;

  const CanonicalIngestInput({
    this.taxpayerId,
    this.branchCd,
    this.sourceSystem = 'IES_UI',
    this.externalRefId,
    this.compInvoiceId,
    this.systemType = 'CAS',
    this.docType = '01',
    this.transClass,
    this.direction = 'SALES',
    this.isPaid = false,
    this.issueDtm,
    this.corrYN,
    this.refEisUniqueId,
    required this.buyerName,
    this.buyerTin,
    this.buyerBranchCd,
    this.buyerCategory = 'REGULAR',
    this.osacaPwdId,
    this.buyerAddress,
    required this.items,
    this.otherChargesAmt = 0.0,
  });

  factory CanonicalIngestInput.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return CanonicalIngestInput(
      taxpayerId: json['taxpayerId']?.toString(),
      branchCd: json['branchCd']?.toString(),
      sourceSystem: json['sourceSystem']?.toString() ?? 'IES_UI',
      externalRefId: json['externalRefId']?.toString(),
      compInvoiceId: json['compInvoiceId']?.toString(),
      systemType: json['systemType']?.toString() ?? 'CAS',
      docType: json['docType']?.toString() ?? '01',
      transClass: json['transClass']?.toString(),
      direction: json['direction']?.toString() ?? 'SALES',
      isPaid: json['isPaid'] == true,
      issueDtm: json['issueDtm']?.toString(),
      corrYN: json['corrYN']?.toString(),
      refEisUniqueId: json['refEisUniqueId']?.toString(),
      buyerName: json['buyerName']?.toString() ?? '',
      buyerTin: json['buyerTin']?.toString(),
      buyerBranchCd: json['buyerBranchCd']?.toString(),
      buyerCategory: json['buyerCategory']?.toString() ?? 'REGULAR',
      osacaPwdId: json['osacaPwdId']?.toString(),
      buyerAddress: json['buyerAddress'] is Map<String, dynamic>
          ? BirAddress.fromJson(json['buyerAddress'] as Map<String, dynamic>)
          : null,
      items: rawItems
          .map((e) => RawLineItemInput.fromJson(e as Map<String, dynamic>))
          .toList(),
      otherChargesAmt: (json['otherChargesAmt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

String _mapXeroTaxType(String? taxType) {
  switch (taxType) {
    case 'EXEMPTOUTPUT':
    case 'NONE':
      return 'VAT_EXEMPT';
    case 'ZERORATEDOUTPUT':
      return 'ZERO_RATED';
    default:
      return 'VATABLE';
  }
}

CanonicalIngestInput mapXeroToCanonical(
  Map<String, dynamic> xero, {
  String? taxpayerId,
}) {
  final contact = (xero['Contact'] as Map<String, dynamic>?) ?? const {};
  final rawTin = contact['TaxNumber']?.toString();
  final tin = (rawTin != null && rawTin.isNotEmpty) ? normalizeTin9(rawTin) : null;
  final addrs = (contact['Addresses'] as List<dynamic>?) ?? const [];
  final addr =
      addrs.isNotEmpty ? (addrs.first as Map<String, dynamic>) : null;
  final lineItems = (xero['LineItems'] as List<dynamic>?) ?? const [];

  return CanonicalIngestInput(
    taxpayerId: taxpayerId,
    sourceSystem: 'XERO',
    externalRefId: xero['InvoiceID']?.toString(),
    compInvoiceId: xero['InvoiceNumber']?.toString(),
    systemType: 'CAS',
    docType: '01',
    transClass: tin != null ? 'B2B' : 'B2C',
    direction: xero['Type'] == 'ACCPAY' ? 'PURCHASE' : 'SALES',
    isPaid: xero['Status'] == 'PAID',
    issueDtm: xero['DateString']?.toString(),
    buyerName: contact['Name']?.toString() ?? 'Xero Contact',
    buyerTin: tin,
    buyerBranchCd: tin != null ? '0000' : null,
    buyerAddress: addr != null
        ? BirAddress(
            street: addr['AddressLine1']?.toString() ?? 'N/A',
            barangay: 'N/A',
            city: addr['City']?.toString() ?? 'Makati City',
            province: addr['Region']?.toString() ?? 'Metro Manila',
            zipCode: addr['PostalCode']?.toString() ?? '1200',
          )
        : null,
    items: lineItems.map((e) {
      final li = e as Map<String, dynamic>;
      return RawLineItemInput(
        itemCd: li['ItemCode']?.toString(),
        itemNm: li['Description']?.toString() ?? 'Item',
        qty: (li['Quantity'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (li['UnitAmount'] as num?)?.toDouble() ?? 0.0,
        taxClassification: _mapXeroTaxType(li['TaxType']?.toString()),
        regularDiscountAmt:
            (li['DiscountAmount'] as num?)?.toDouble() ?? 0.0,
        atcCode: li['AtcCode']?.toString(),
      );
    }).toList(),
  );
}

CanonicalIngestInput mapQuickBooksToCanonical(
  Map<String, dynamic> qbo, {
  String? taxpayerId,
}) {
  final cust = (qbo['CustomerRef'] as Map<String, dynamic>?) ?? const {};
  final rawTin = cust['tin']?.toString();
  final tin = (rawTin != null && rawTin.isNotEmpty) ? normalizeTin9(rawTin) : null;
  final txnType = qbo['TxnType']?.toString();
  final docType = txnType == 'CreditMemo' ? '03' : '01';
  final lines = (qbo['Line'] as List<dynamic>?) ?? const [];

  return CanonicalIngestInput(
    taxpayerId: taxpayerId,
    sourceSystem: 'QUICKBOOKS',
    externalRefId: qbo['Id']?.toString(),
    compInvoiceId: qbo['DocNumber']?.toString(),
    systemType: 'CAS',
    docType: docType,
    transClass: tin != null ? 'B2B' : 'B2C',
    direction: txnType == 'Bill' ? 'PURCHASE' : 'SALES',
    isPaid: false,
    issueDtm: qbo['TxnDate'] != null ? '${qbo['TxnDate']}T12:00:00' : null,
    corrYN: docType == '03' ? 'Y' : 'N',
    buyerName: cust['name']?.toString() ?? 'QuickBooks Customer',
    buyerTin: tin,
    buyerBranchCd:
        tin != null ? normalizeBranchCd(cust['branchCd']?.toString()) : null,
    items: lines
        .where(
          (l) => (l as Map<String, dynamic>)['SalesItemLineDetail'] != null,
        )
        .map((l) {
      final lineMap = l as Map<String, dynamic>;
      final detail = lineMap['SalesItemLineDetail'] as Map<String, dynamic>;
      final taxCode =
          (detail['TaxCodeRef'] as Map<String, dynamic>?)?['value']?.toString();
      final taxClassification = taxCode == 'EXEMPT'
          ? 'VAT_EXEMPT'
          : taxCode == 'ZERO'
              ? 'ZERO_RATED'
              : 'VATABLE';
      final itemRef = detail['ItemRef'] as Map<String, dynamic>?;
      return RawLineItemInput(
        itemCd: itemRef?['value']?.toString(),
        itemNm: lineMap['Description']?.toString() ??
            itemRef?['name']?.toString() ??
            'Service Item',
        qty: (detail['Qty'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (detail['UnitPrice'] as num?)?.toDouble() ?? 0.0,
        taxClassification: taxClassification,
        atcCode: detail['AtcCode']?.toString(),
      );
    }).toList(),
  );
}

CanonicalIngestInput mapOdooToCanonical(
  Map<String, dynamic> odoo, {
  String? taxpayerId,
}) {
  final partner = (odoo['partner_id'] as Map<String, dynamic>?) ?? const {};
  final rawTin = partner['vat']?.toString();
  final tin = (rawTin != null && rawTin.isNotEmpty) ? normalizeTin9(rawTin) : null;
  final moveType = odoo['move_type']?.toString() ?? 'out_invoice';
  final docType = moveType == 'out_refund' ? '03' : '02';
  final lines = (odoo['invoice_line_ids'] as List<dynamic>?) ?? const [];

  return CanonicalIngestInput(
    taxpayerId: taxpayerId,
    sourceSystem: 'ODOO',
    externalRefId: odoo['id']?.toString(),
    compInvoiceId: odoo['name']?.toString(),
    systemType: 'CAS',
    docType: docType,
    transClass: tin != null ? 'B2B' : 'B2C',
    direction: moveType == 'in_invoice' ? 'PURCHASE' : 'SALES',
    isPaid: false,
    issueDtm:
        odoo['invoice_date'] != null ? '${odoo['invoice_date']}T12:00:00' : null,
    corrYN: docType == '03' ? 'Y' : 'N',
    buyerName: partner['name']?.toString() ?? 'Odoo Partner',
    buyerTin: tin,
    buyerBranchCd: tin != null ? '0000' : null,
    buyerAddress: partner['street'] != null
        ? BirAddress(
            street: partner['street'].toString(),
            barangay: 'N/A',
            city: partner['city']?.toString() ?? 'Taguig City',
            province: 'Metro Manila',
            zipCode: partner['zip']?.toString() ?? '1634',
          )
        : null,
    items: lines.map((l) {
      final line = l as Map<String, dynamic>;
      final taxIds = (line['tax_ids'] as List<dynamic>?) ?? const ['VAT_12'];
      final tag = taxIds.isNotEmpty ? taxIds.first.toString() : 'VAT_12';
      final taxClassification = tag == 'VAT_EXEMPT'
          ? 'VAT_EXEMPT'
          : tag == 'VAT_ZERO'
              ? 'ZERO_RATED'
              : 'VATABLE';
      return RawLineItemInput(
        itemCd: line['product_code']?.toString(),
        itemNm: line['name']?.toString() ?? 'Odoo Line',
        qty: (line['quantity'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (line['price_unit'] as num?)?.toDouble() ?? 0.0,
        taxClassification: taxClassification,
        atcCode: line['l10n_ph_atc']?.toString(),
      );
    }).toList(),
  );
}

List<CanonicalIngestInput> parseCsvBatchToCanonical(
  String csvText, {
  String? taxpayerId,
}) {
  final lines = csvText
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length < 2) return const [];

  final grouped = <String, List<RawLineItemInput>>{};
  final headers = <String, CanonicalIngestInput>{};

  for (final row in lines.skip(1)) {
    final cols = row
        .split(',')
        .map((c) => c.trim().replaceAll(RegExp(r'^"|"$'), ''))
        .toList();
    if (cols.length < 8) continue;

    final compInvoiceId = cols[0];
    final buyerName = cols[1];
    final buyerTinRaw = cols[2];
    final docType = cols[3].isNotEmpty ? cols[3] : '01';
    final transClass = cols[4];
    final itemNm = cols[5];
    final qty = double.tryParse(cols[6]) ?? 1.0;
    final unitPrice = double.tryParse(cols[7]) ?? 0.0;
    final taxClass = cols.length > 8 && cols[8].isNotEmpty ? cols[8] : 'VATABLE';
    final atcCode = cols.length > 9 && cols[9].isNotEmpty ? cols[9] : null;

    if (compInvoiceId.isEmpty || buyerName.isEmpty || itemNm.isEmpty) continue;

    final tin = buyerTinRaw.isNotEmpty ? normalizeTin9(buyerTinRaw) : null;
    final item = RawLineItemInput(
      itemNm: itemNm,
      qty: qty,
      unitPrice: unitPrice,
      taxClassification: taxClass,
      atcCode: atcCode,
    );

    grouped.putIfAbsent(compInvoiceId, () => []).add(item);
    headers.putIfAbsent(
      compInvoiceId,
      () => CanonicalIngestInput(
        taxpayerId: taxpayerId,
        sourceSystem: 'CSV_BATCH',
        compInvoiceId: compInvoiceId,
        systemType: 'CAS',
        docType: docType,
        transClass: transClass.isNotEmpty
            ? transClass
            : (tin != null ? 'B2B' : 'B2C'),
        buyerName: buyerName,
        buyerTin: tin,
        buyerBranchCd: tin != null ? '0000' : null,
        items: grouped[compInvoiceId]!,
      ),
    );
  }

  return headers.values.toList();
}
