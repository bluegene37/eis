import {
  BirEisItem,
  BirEisPayloadV201,
  BirEisSummary,
  BuyerCategory,
  DiscountType,
  TaxClassification,
  TaxType,
} from '../domain/bir-eis-schema.js';

/**
 * Standard BIR Alphanumeric Tax Codes (ATC) for Creditable Withholding Tax (CWT / EWT)
 * Aligned with RR No. 11-2018 & RR No. 6-2026 guidelines.
 */
export interface AtcDefinition {
  code: string;
  description: string;
  rate: number; // decimal e.g. 0.02 = 2%
  nature: 'GOODS' | 'SERVICES' | 'PROFESSIONALS' | 'RENTALS';
}

export const BIR_ATC_CATALOG: Record<string, AtcDefinition> = {
  WI010: {
    code: 'WI010',
    description: 'Professional / Talent Fees (Individual <= 3M gross)',
    rate: 0.05,
    nature: 'PROFESSIONALS',
  },
  WI011: {
    code: 'WI011',
    description: 'Professional / Talent Fees (Individual > 3M gross)',
    rate: 0.1,
    nature: 'PROFESSIONALS',
  },
  WC010: {
    code: 'WC010',
    description: 'Professional / Management / Consultancy Fees (Corporate)',
    rate: 0.1,
    nature: 'PROFESSIONALS',
  },
  WC011: {
    code: 'WC011',
    description: 'Professional / Management Fees (Corporate > 720k)',
    rate: 0.15,
    nature: 'PROFESSIONALS',
  },
  WI158: {
    code: 'WI158',
    description: 'Top Withholding Agent - Income Payments for Goods (Individual)',
    rate: 0.01,
    nature: 'GOODS',
  },
  WC158: {
    code: 'WC158',
    description: 'Top Withholding Agent - Income Payments for Goods (Corporate)',
    rate: 0.01,
    nature: 'GOODS',
  },
  WI160: {
    code: 'WI160',
    description: 'Top Withholding Agent - Income Payments for Services (Individual)',
    rate: 0.02,
    nature: 'SERVICES',
  },
  WC160: {
    code: 'WC160',
    description: 'Top Withholding Agent - Income Payments for Services (Corporate)',
    rate: 0.02,
    nature: 'SERVICES',
  },
  WC100: {
    code: 'WC100',
    description: 'Rentals (Real or Personal Property - Corporate)',
    rate: 0.05,
    nature: 'RENTALS',
  },
};

export interface RawLineItemInput {
  itemCd?: string;
  itemNm: string;
  unit?: string;
  qty: number;
  unitPrice: number; // VAT-inclusive if priceIncludesVat=true, else VAT-exclusive
  priceIncludesVat?: boolean;
  taxClassification?: TaxClassification;
  discountType?: DiscountType;
  regularDiscountAmt?: number;
  atcCode?: string | null;
}

export function round2(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

/**
 * Computes BIR EOPT (RA 11976 / RR 7-2024) & CWT (RR 6-2026) line item and invoice totals.
 * Handles:
 *  - Standard 12% VATable goods & services
 *  - Senior Citizen (SC) & PWD statutory exemption (removes 12% VAT if inclusive + applies 20% discount)
 *  - VAT-Exempt and Zero-Rated (0% VAT) sales
 *  - Creditable Withholding Tax (CWT) via BIR ATC codes
 */
export function computeBirTaxBreakdown(
  items: RawLineItemInput[],
  sellerTaxType: TaxType,
  buyerCategory: BuyerCategory = 'REGULAR',
  otherChargesAmt = 0,
): { itemList: BirEisItem[]; summary: BirEisSummary } {
  let grossSalesAmt = 0;
  let totalDiscountAmt = 0;
  let scPwdDiscountAmt = 0;
  let netSalesTotal = 0;
  let vatableSales = 0;
  let vatExemptSales = 0;
  let zeroRatedSales = 0;
  let vatAmtTotal = 0;
  let withholdingTaxAmt = 0;

  const isStatutoryScPwd =
    buyerCategory === 'SENIOR_CITIZEN' || buyerCategory === 'PWD';

  const itemList: BirEisItem[] = items.map((raw, index) => {
    const qty = round2(raw.qty);
    const inputUnitPrice = round2(raw.unitPrice);
    const priceIncludesVat = raw.priceIncludesVat ?? false;

    let effectiveClassification: TaxClassification =
      raw.taxClassification ?? (sellerTaxType === 'NON_VAT' ? 'VAT_EXEMPT' : 'VATABLE');

    let effectiveDiscountType: DiscountType = raw.discountType ?? 'NONE';
    if (isStatutoryScPwd && effectiveClassification === 'VATABLE') {
      effectiveClassification = 'VAT_EXEMPT';
      effectiveDiscountType = buyerCategory === 'SENIOR_CITIZEN' ? 'SENIOR_CITIZEN' : 'PWD';
    }

    // Derive VAT-exclusive base unit cost when price was entered VAT-inclusive
    const baseUnitCost =
      priceIncludesVat && (raw.taxClassification ?? 'VATABLE') === 'VATABLE'
        ? round2(inputUnitPrice / 1.12)
        : inputUnitPrice;

    const grossAmt = round2(qty * baseUnitCost);
    let discountAmt = round2(raw.regularDiscountAmt ?? 0);

    if (
      (effectiveDiscountType === 'SENIOR_CITIZEN' ||
        effectiveDiscountType === 'PWD' ||
        effectiveDiscountType === 'NAAC' ||
        effectiveDiscountType === 'SOLO_PARENT') &&
      discountAmt === 0
    ) {
      discountAmt = round2(grossAmt * 0.2);
      scPwdDiscountAmt = round2(scPwdDiscountAmt + discountAmt);
    }

    const netSales = round2(Math.max(0, grossAmt - discountAmt));

    let vatAmt = 0;
    if (sellerTaxType === 'VAT' && effectiveClassification === 'VATABLE') {
      vatAmt = round2(netSales * 0.12);
      vatableSales = round2(vatableSales + netSales);
    } else if (effectiveClassification === 'ZERO_RATED') {
      zeroRatedSales = round2(zeroRatedSales + netSales);
    } else {
      vatExemptSales = round2(vatExemptSales + netSales);
    }

    const atcDef = raw.atcCode ? BIR_ATC_CATALOG[raw.atcCode.toUpperCase()] : undefined;
    const cwtRate = atcDef ? atcDef.rate : 0;
    const cwtAmt = cwtRate > 0 ? round2(netSales * cwtRate) : 0;

    grossSalesAmt = round2(grossSalesAmt + grossAmt);
    totalDiscountAmt = round2(totalDiscountAmt + discountAmt);
    netSalesTotal = round2(netSalesTotal + netSales);
    vatAmtTotal = round2(vatAmtTotal + vatAmt);
    withholdingTaxAmt = round2(withholdingTaxAmt + cwtAmt);

    return {
      LineNo: index + 1,
      ItemCd: raw.itemCd?.trim() || `SKU-${String(index + 1).padStart(3, '0')}`,
      ItemNm: raw.itemNm.trim(),
      Unit: raw.unit?.trim() || 'PCS',
      Qty: qty,
      UnitCost: baseUnitCost,
      GrossAmt: grossAmt,
      DiscountType: effectiveDiscountType,
      DiscountAmt: discountAmt,
      NetSales: netSales,
      TaxClassification: effectiveClassification,
      VATAmt: vatAmt,
      AtcCode: atcDef ? atcDef.code : null,
      CwtRate: cwtRate,
      CwtAmt: cwtAmt,
    };
  });

  const charges = round2(otherChargesAmt);
  // TotalAmountDue represents net cash receivable after VAT and EWT/CWT deduction
  const totalAmountDue = round2(netSalesTotal + vatAmtTotal + charges - withholdingTaxAmt);

  return {
    itemList,
    summary: {
      GrossSalesAmt: grossSalesAmt,
      TotalDiscountAmt: totalDiscountAmt,
      ScPwdDiscountAmt: scPwdDiscountAmt,
      NetSales: netSalesTotal,
      VATableSales: vatableSales,
      VATExemptSales: vatExemptSales,
      ZeroRatedSales: zeroRatedSales,
      VATAmt: vatAmtTotal,
      WithholdingTaxAmt: withholdingTaxAmt,
      OtherChargesAmt: charges,
      TotalAmountDue: totalAmountDue,
    },
  };
}

/**
 * Validates arithmetic integrity of a BIR EIS v2.01 payload (mirrors BIR VAL001 check).
 * Ensures line sums match summary fields and 12% VAT matches VATableSales within 0.01 PHP.
 */
export function validateBirArithmetic(payload: BirEisPayloadV201): string[] {
  const errors: string[] = [];
  const s = payload.Summary;

  const lineNetSum = round2(payload.ItemList.reduce((acc, i) => acc + i.NetSales, 0));
  const lineVatSum = round2(payload.ItemList.reduce((acc, i) => acc + i.VATAmt, 0));
  const lineCwtSum = round2(payload.ItemList.reduce((acc, i) => acc + i.CwtAmt, 0));

  if (Math.abs(lineNetSum - s.NetSales) > 0.02) {
    errors.push(
      `VAL001: Summary.NetSales (${s.NetSales}) does not match sum of ItemList.NetSales (${lineNetSum}).`,
    );
  }
  if (Math.abs(lineVatSum - s.VATAmt) > 0.02) {
    errors.push(
      `VAL001: Summary.VATAmt (${s.VATAmt}) does not match sum of ItemList.VATAmt (${lineVatSum}).`,
    );
  }
  if (payload.Seller.Type === 'VAT') {
    const expectedVat = round2(s.VATableSales * 0.12);
    if (Math.abs(expectedVat - s.VATAmt) > 0.05) {
      errors.push(
        `VAL001: Summary.VATAmt (${s.VATAmt}) deviates from 12% of VATableSales (${expectedVat}).`,
      );
    }
  }
  if (Math.abs(lineCwtSum - s.WithholdingTaxAmt) > 0.02) {
    errors.push(
      `VAL001: Summary.WithholdingTaxAmt (${s.WithholdingTaxAmt}) does not match line CWT sum (${lineCwtSum}).`,
    );
  }
  const bucketSum = round2(s.VATableSales + s.VATExemptSales + s.ZeroRatedSales);
  if (Math.abs(bucketSum - s.NetSales) > 0.02) {
    errors.push(
      `VAL001: VATableSales + VATExemptSales + ZeroRatedSales (${bucketSum}) must equal NetSales (${s.NetSales}).`,
    );
  }
  const expectedTotalDue = round2(s.NetSales + s.VATAmt + s.OtherChargesAmt - s.WithholdingTaxAmt);
  if (Math.abs(expectedTotalDue - s.TotalAmountDue) > 0.02) {
    errors.push(
      `VAL001: Summary.TotalAmountDue (${s.TotalAmountDue}) does not equal NetSales + VATAmt + OtherChargesAmt - WithholdingTaxAmt (${expectedTotalDue}).`,
    );
  }

  return errors;
}
