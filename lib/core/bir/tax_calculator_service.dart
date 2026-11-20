// Gene - Nov, 20, 2026: Ported from eis pure-Dart BIR EIS/CAS engine.
import 'bir_eis_schema.dart';

class AtcDefinition {
  final String code;
  final String description;
  final double rate;
  final String nature;

  const AtcDefinition({
    required this.code,
    required this.description,
    required this.rate,
    required this.nature,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'description': description,
        'rate': rate,
        'nature': nature,
      };
}

const Map<String, AtcDefinition> birAtcCatalog = {
  'WI010': AtcDefinition(
    code: 'WI010',
    description: 'Professional / Talent Fees (Individual <= 3M gross)',
    rate: 0.05,
    nature: 'PROFESSIONALS',
  ),
  'WI011': AtcDefinition(
    code: 'WI011',
    description: 'Professional / Talent Fees (Individual > 3M gross)',
    rate: 0.10,
    nature: 'PROFESSIONALS',
  ),
  'WC010': AtcDefinition(
    code: 'WC010',
    description: 'Professional / Management / Consultancy Fees (Corporate)',
    rate: 0.10,
    nature: 'PROFESSIONALS',
  ),
  'WC011': AtcDefinition(
    code: 'WC011',
    description: 'Professional / Management Fees (Corporate > 720k)',
    rate: 0.15,
    nature: 'PROFESSIONALS',
  ),
  'WI158': AtcDefinition(
    code: 'WI158',
    description: 'Top Withholding Agent - Income Payments for Goods (Individual)',
    rate: 0.01,
    nature: 'GOODS',
  ),
  'WC158': AtcDefinition(
    code: 'WC158',
    description: 'Top Withholding Agent - Income Payments for Goods (Corporate)',
    rate: 0.01,
    nature: 'GOODS',
  ),
  'WI160': AtcDefinition(
    code: 'WI160',
    description: 'Top Withholding Agent - Income Payments for Services (Individual)',
    rate: 0.02,
    nature: 'SERVICES',
  ),
  'WC160': AtcDefinition(
    code: 'WC160',
    description: 'Top Withholding Agent - Income Payments for Services (Corporate)',
    rate: 0.02,
    nature: 'SERVICES',
  ),
  'WC100': AtcDefinition(
    code: 'WC100',
    description: 'Rentals (Real or Personal Property - Corporate)',
    rate: 0.05,
    nature: 'RENTALS',
  ),
};

class RawLineItemInput {
  final String? itemCd;
  final String itemNm;
  final String unit;
  final double qty;
  final double unitPrice;
  final bool priceIncludesVat;
  final String? taxClassification;
  final String? discountType;
  final double regularDiscountAmt;
  final String? atcCode;

  const RawLineItemInput({
    this.itemCd,
    required this.itemNm,
    this.unit = 'PCS',
    required this.qty,
    required this.unitPrice,
    this.priceIncludesVat = false,
    this.taxClassification,
    this.discountType,
    this.regularDiscountAmt = 0.0,
    this.atcCode,
  });

  factory RawLineItemInput.fromJson(Map<String, dynamic> json) =>
      RawLineItemInput(
        itemCd: json['itemCd']?.toString(),
        itemNm: json['itemNm']?.toString() ?? '',
        unit: json['unit']?.toString() ?? 'PCS',
        qty: (json['qty'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        priceIncludesVat: json['priceIncludesVat'] == true,
        taxClassification: json['taxClassification']?.toString(),
        discountType: json['discountType']?.toString(),
        regularDiscountAmt:
            (json['regularDiscountAmt'] as num?)?.toDouble() ?? 0.0,
        atcCode: json['atcCode']?.toString(),
      );
}

double round2(double value) => (value * 100).roundToDouble() / 100.0;

({List<BirEisItem> itemList, BirEisSummary summary}) computeBirTaxBreakdown(
  List<RawLineItemInput> items,
  String sellerTaxType, {
  String buyerCategory = 'REGULAR',
  double otherChargesAmt = 0.0,
}) {
  var grossSalesAmt = 0.0;
  var totalDiscountAmt = 0.0;
  var scPwdDiscountAmt = 0.0;
  var netSalesTotal = 0.0;
  var vatableSales = 0.0;
  var vatExemptSales = 0.0;
  var zeroRatedSales = 0.0;
  var vatAmtTotal = 0.0;
  var withholdingTaxAmt = 0.0;

  final isStatutoryScPwd =
      buyerCategory == 'SENIOR_CITIZEN' || buyerCategory == 'PWD';

  final itemList = <BirEisItem>[];
  for (var index = 0; index < items.length; index++) {
    final raw = items[index];
    final qty = round2(raw.qty);
    final inputUnitPrice = round2(raw.unitPrice);

    var effectiveClassification = raw.taxClassification ??
        (sellerTaxType == 'NON_VAT' ? 'VAT_EXEMPT' : 'VATABLE');

    var effectiveDiscountType = raw.discountType ?? 'NONE';
    if (isStatutoryScPwd && effectiveClassification == 'VATABLE') {
      effectiveClassification = 'VAT_EXEMPT';
      effectiveDiscountType =
          buyerCategory == 'SENIOR_CITIZEN' ? 'SENIOR_CITIZEN' : 'PWD';
    }

    final baseUnitCost = raw.priceIncludesVat &&
            (raw.taxClassification ?? 'VATABLE') == 'VATABLE'
        ? round2(inputUnitPrice / 1.12)
        : inputUnitPrice;

    final grossAmt = round2(qty * baseUnitCost);
    var discountAmt = round2(raw.regularDiscountAmt);

    if ((effectiveDiscountType == 'SENIOR_CITIZEN' ||
            effectiveDiscountType == 'PWD' ||
            effectiveDiscountType == 'NAAC' ||
            effectiveDiscountType == 'SOLO_PARENT') &&
        discountAmt == 0) {
      discountAmt = round2(grossAmt * 0.2);
      scPwdDiscountAmt = round2(scPwdDiscountAmt + discountAmt);
    }

    final netSales = round2((grossAmt - discountAmt).clamp(0.0, double.infinity));

    var vatAmt = 0.0;
    if (sellerTaxType == 'VAT' && effectiveClassification == 'VATABLE') {
      vatAmt = round2(netSales * 0.12);
      vatableSales = round2(vatableSales + netSales);
    } else if (effectiveClassification == 'ZERO_RATED') {
      zeroRatedSales = round2(zeroRatedSales + netSales);
    } else {
      vatExemptSales = round2(vatExemptSales + netSales);
    }

    final atcDef =
        raw.atcCode != null ? birAtcCatalog[raw.atcCode!.toUpperCase()] : null;
    final cwtRate = atcDef?.rate ?? 0.0;
    final cwtAmt = cwtRate > 0 ? round2(netSales * cwtRate) : 0.0;

    grossSalesAmt = round2(grossSalesAmt + grossAmt);
    totalDiscountAmt = round2(totalDiscountAmt + discountAmt);
    netSalesTotal = round2(netSalesTotal + netSales);
    vatAmtTotal = round2(vatAmtTotal + vatAmt);
    withholdingTaxAmt = round2(withholdingTaxAmt + cwtAmt);

    itemList.add(
      BirEisItem(
        lineNo: index + 1,
        itemCd: (raw.itemCd != null && raw.itemCd!.trim().isNotEmpty)
            ? raw.itemCd!.trim()
            : 'SKU-${(index + 1).toString().padLeft(3, '0')}',
        itemNm: raw.itemNm.trim(),
        unit: raw.unit.trim().isEmpty ? 'PCS' : raw.unit.trim(),
        qty: qty,
        unitCost: baseUnitCost,
        grossAmt: grossAmt,
        discountType: effectiveDiscountType,
        discountAmt: discountAmt,
        netSales: netSales,
        taxClassification: effectiveClassification,
        vatAmt: vatAmt,
        atcCode: atcDef?.code,
        cwtRate: cwtRate,
        cwtAmt: cwtAmt,
      ),
    );
  }

  final charges = round2(otherChargesAmt);
  final totalAmountDue =
      round2(netSalesTotal + vatAmtTotal + charges - withholdingTaxAmt);

  return (
    itemList: itemList,
    summary: BirEisSummary(
      grossSalesAmt: grossSalesAmt,
      totalDiscountAmt: totalDiscountAmt,
      scPwdDiscountAmt: scPwdDiscountAmt,
      netSales: netSalesTotal,
      vatableSales: vatableSales,
      vatExemptSales: vatExemptSales,
      zeroRatedSales: zeroRatedSales,
      vatAmt: vatAmtTotal,
      withholdingTaxAmt: withholdingTaxAmt,
      otherChargesAmt: charges,
      totalAmountDue: totalAmountDue,
    ),
  );
}

List<String> validateBirArithmetic(BirEisPayloadV201 payload) {
  final errors = <String>[];
  final s = payload.summary;

  final lineNetSum =
      round2(payload.itemList.fold(0.0, (acc, i) => acc + i.netSales));
  final lineVatSum =
      round2(payload.itemList.fold(0.0, (acc, i) => acc + i.vatAmt));
  final lineCwtSum =
      round2(payload.itemList.fold(0.0, (acc, i) => acc + i.cwtAmt));

  if ((lineNetSum - s.netSales).abs() > 0.02) {
    errors.add(
      'VAL001: Summary.NetSales (${s.netSales}) does not match sum of ItemList.NetSales ($lineNetSum).',
    );
  }
  if ((lineVatSum - s.vatAmt).abs() > 0.02) {
    errors.add(
      'VAL001: Summary.VATAmt (${s.vatAmt}) does not match sum of ItemList.VATAmt ($lineVatSum).',
    );
  }
  if (payload.seller.type == 'VAT') {
    final expectedVat = round2(s.vatableSales * 0.12);
    if ((expectedVat - s.vatAmt).abs() > 0.05) {
      errors.add(
        'VAL001: Summary.VATAmt (${s.vatAmt}) deviates from 12% of VATableSales ($expectedVat).',
      );
    }
  }
  if ((lineCwtSum - s.withholdingTaxAmt).abs() > 0.02) {
    errors.add(
      'VAL001: Summary.WithholdingTaxAmt (${s.withholdingTaxAmt}) does not match line CWT sum ($lineCwtSum).',
    );
  }
  final bucketSum =
      round2(s.vatableSales + s.vatExemptSales + s.zeroRatedSales);
  if ((bucketSum - s.netSales).abs() > 0.02) {
    errors.add(
      'VAL001: VATableSales + VATExemptSales + ZeroRatedSales ($bucketSum) must equal NetSales (${s.netSales}).',
    );
  }
  final expectedTotalDue = round2(
    s.netSales + s.vatAmt + s.otherChargesAmt - s.withholdingTaxAmt,
  );
  if ((expectedTotalDue - s.totalAmountDue).abs() > 0.02) {
    errors.add(
      'VAL001: Summary.TotalAmountDue (${s.totalAmountDue}) does not equal NetSales + VATAmt + OtherChargesAmt - WithholdingTaxAmt ($expectedTotalDue).',
    );
  }

  return errors;
}
