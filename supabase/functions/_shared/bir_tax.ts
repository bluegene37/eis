// Gene - Nov, 24, 2026: Philippine BIR EIS v2.01 schema types, exact integer-centavo EOPT/CWT math,
// and SYN004 / VAL001 validators.

export interface BirAddress {
  Street: string;
  Barangay: string;
  City: string;
  Province: string;
  ZipCode: string;
}

export interface SellerInfo {
  TIN: string;
  BranchCd: string;
  Type: 'VAT' | 'NON_VAT' | string;
  RegNm: string;
  BusinessNm: string;
  Address: BirAddress;
  Email: string;
}

export interface BuyerInfo {
  TIN: string | null;
  BranchCd: string | null;
  RegNm: string;
  Address: BirAddress | null;
  BuyerCategory: string;
  OsacaPwdId?: string | null;
}

export interface BirEisItem {
  LineNo: number;
  ItemCd: string;
  ItemNm: string;
  Unit: string;
  Qty: number;
  UnitCost: number;
  GrossAmt: number;
  DiscountType: string;
  DiscountAmt: number;
  NetSales: number;
  TaxClassification: string;
  VATAmt: number;
  AtcCode: string | null;
  CwtRate: number;
  CwtAmt: number;
}

export interface BirEisSummary {
  GrossSalesAmt: number;
  TotalDiscountAmt: number;
  ScPwdDiscountAmt: number;
  NetSales: number;
  VATableSales: number;
  VATExemptSales: number;
  ZeroRatedSales: number;
  VATAmt: number;
  WithholdingTaxAmt: number;
  OtherChargesAmt: number;
  TotalAmountDue: number;
}

export interface BirEisPayloadV201 {
  SchemaVer: string;
  SystemType: string;
  EisUniqueId: string;
  CompInvoiceId: string;
  IssueDtm: string;
  DocType: string;
  TransClass: string;
  CorrYN: string;
  RefEisUniqueId: string | null;
  Currency: string;
  Seller: SellerInfo;
  Buyer: BuyerInfo;
  ItemList: BirEisItem[];
  Summary: BirEisSummary;
}

export interface RawLineItemInput {
  itemCd?: string | null;
  itemNm: string;
  unit?: string;
  qty: number;
  unitPrice: number;
  priceIncludesVat?: boolean;
  taxClassification?: string | null;
  discountType?: string | null;
  regularDiscountAmt?: number;
  atcCode?: string | null;
}

export interface CanonicalIngestInput {
  taxpayerId?: string | null;
  branchCd?: string | null;
  sourceSystem: string;
  externalRefId?: string | null;
  compInvoiceId?: string | null;
  systemType: string;
  docType: string;
  transClass?: string | null;
  direction: 'SALES' | 'PURCHASE' | string;
  isPaid: boolean;
  issueDtm?: string | null;
  corrYN?: string | null;
  refEisUniqueId?: string | null;
  buyerName: string;
  buyerTin?: string | null;
  buyerBranchCd?: string | null;
  buyerCategory: string;
  osacaPwdId?: string | null;
  buyerAddress?: BirAddress | null;
  items: RawLineItemInput[];
  otherChargesAmt: number;
}

export interface AtcDefinition {
  code: string;
  description: string;
  rate: number;
  nature: string;
}

export const birAtcCatalog: Record<string, AtcDefinition> = {
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

export function toCents(amount: number): number {
  return Math.round((Number.isFinite(amount) ? amount : 0) * 100);
}

export function fromCents(cents: number): number {
  return Number((cents / 100).toFixed(2));
}

export function round2(value: number): number {
  return fromCents(toCents(value));
}

export function normalizeTin9(rawTin: string): string {
  const digits = rawTin.replace(/\D/g, '');
  if (digits.length >= 9) {
    return digits.slice(0, 9);
  }
  return digits.padStart(9, '0');
}

export function normalizeBranchCd(rawBranch?: string | null): string {
  const digits = (rawBranch ?? '0000').replace(/\D/g, '');
  const clipped = digits.length > 4 ? digits.slice(0, 4) : digits;
  return clipped.padStart(4, '0');
}

export function normalizeAddress(input?: Record<string, unknown> | null): BirAddress {
  const src = input ?? {};
  return {
    Street: String(src['Street'] ?? src['street'] ?? ''),
    Barangay: String(src['Barangay'] ?? src['barangay'] ?? ''),
    City: String(src['City'] ?? src['city'] ?? ''),
    Province: String(src['Province'] ?? src['province'] ?? ''),
    ZipCode: String(src['ZipCode'] ?? src['zipCode'] ?? ''),
  };
}

export function buildEisUniqueId(
  issueDate: Date,
  eisCertId: string,
  sequenceNumber: number,
): string {
  const yyyy = issueDate.getFullYear().toString();
  const mm = (issueDate.getMonth() + 1).toString().padStart(2, '0');
  const dd = issueDate.getDate().toString().padStart(2, '0');
  const cert = eisCertId
    .replace(/[^A-Za-z0-9]/g, '')
    .toUpperCase()
    .padEnd(8, '0')
    .slice(0, 8);
  const seqRaw = Math.trunc(sequenceNumber).toString().padStart(8, '0');
  const seq = seqRaw.slice(seqRaw.length - 8);
  return `${yyyy}${mm}${dd}${cert}${seq}`;
}

export function formatBirDateTime(date: Date): string {
  const p = (n: number) => n.toString().padStart(2, '0');
  return `${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}T${p(date.getHours())}:${p(date.getMinutes())}:${p(date.getSeconds())}`;
}

export function parseCanonicalIngestInput(
  json: Record<string, unknown>,
): CanonicalIngestInput {
  const rawItems = Array.isArray(json['items']) ? json['items'] : [];
  return {
    taxpayerId: json['taxpayerId'] != null ? String(json['taxpayerId']) : null,
    branchCd: json['branchCd'] != null ? String(json['branchCd']) : null,
    sourceSystem: String(json['sourceSystem'] ?? 'IES_UI'),
    externalRefId:
      json['externalRefId'] != null ? String(json['externalRefId']) : null,
    compInvoiceId:
      json['compInvoiceId'] != null ? String(json['compInvoiceId']) : null,
    systemType: String(json['systemType'] ?? 'CAS'),
    docType: String(json['docType'] ?? '01'),
    transClass:
      json['transClass'] != null ? String(json['transClass']) : null,
    direction: String(json['direction'] ?? 'SALES'),
    isPaid: json['isPaid'] === true,
    issueDtm: json['issueDtm'] != null ? String(json['issueDtm']) : null,
    corrYN: json['corrYN'] != null ? String(json['corrYN']) : null,
    refEisUniqueId:
      json['refEisUniqueId'] != null ? String(json['refEisUniqueId']) : null,
    buyerName: String(json['buyerName'] ?? ''),
    buyerTin: json['buyerTin'] != null ? String(json['buyerTin']) : null,
    buyerBranchCd:
      json['buyerBranchCd'] != null ? String(json['buyerBranchCd']) : null,
    buyerCategory: String(json['buyerCategory'] ?? 'REGULAR'),
    osacaPwdId:
      json['osacaPwdId'] != null ? String(json['osacaPwdId']) : null,
    buyerAddress:
      json['buyerAddress'] && typeof json['buyerAddress'] === 'object'
        ? normalizeAddress(json['buyerAddress'] as Record<string, unknown>)
        : null,
    items: rawItems.map((entry) => {
      const li = (entry ?? {}) as Record<string, unknown>;
      return {
        itemCd: li['itemCd'] != null ? String(li['itemCd']) : null,
        itemNm: String(li['itemNm'] ?? ''),
        unit: li['unit'] != null ? String(li['unit']) : 'PCS',
        qty: Number(li['qty'] ?? 1),
        unitPrice: Number(li['unitPrice'] ?? 0),
        priceIncludesVat: li['priceIncludesVat'] === true,
        taxClassification:
          li['taxClassification'] != null
            ? String(li['taxClassification'])
            : null,
        discountType:
          li['discountType'] != null ? String(li['discountType']) : null,
        regularDiscountAmt: Number(li['regularDiscountAmt'] ?? 0),
        atcCode: li['atcCode'] != null ? String(li['atcCode']) : null,
      };
    }),
    otherChargesAmt: Number(json['otherChargesAmt'] ?? 0),
  };
}

export function computeBirTaxBreakdown(
  items: RawLineItemInput[],
  sellerTaxType: string,
  options?: {
    buyerCategory?: string;
    otherChargesAmt?: number;
  },
): { itemList: BirEisItem[]; summary: BirEisSummary } {
  const buyerCategory = options?.buyerCategory ?? 'REGULAR';
  const otherChargesAmt = options?.otherChargesAmt ?? 0;

  let grossSalesCents = 0;
  let totalDiscountCents = 0;
  let scPwdDiscountCents = 0;
  let netSalesTotalCents = 0;
  let vatableSalesCents = 0;
  let vatExemptSalesCents = 0;
  let zeroRatedSalesCents = 0;
  let vatAmtTotalCents = 0;
  let withholdingTaxCents = 0;

  const isStatutoryScPwd =
    buyerCategory === 'SENIOR_CITIZEN' || buyerCategory === 'PWD';

  const itemList: BirEisItem[] = [];
  for (let index = 0; index < items.length; index++) {
    const raw = items[index];
    const qty = fromCents(toCents(raw.qty));
    const inputUnitPriceCents = toCents(raw.unitPrice);

    let effectiveClassification =
      raw.taxClassification ??
      (sellerTaxType === 'NON_VAT' ? 'VAT_EXEMPT' : 'VATABLE');

    let effectiveDiscountType = raw.discountType ?? 'NONE';
    if (isStatutoryScPwd && effectiveClassification === 'VATABLE') {
      effectiveClassification = 'VAT_EXEMPT';
      effectiveDiscountType =
        buyerCategory === 'SENIOR_CITIZEN' ? 'SENIOR_CITIZEN' : 'PWD';
    }

    const baseUnitCostCents =
      raw.priceIncludesVat &&
      (raw.taxClassification ?? 'VATABLE') === 'VATABLE'
        ? Math.round(inputUnitPriceCents / 1.12)
        : inputUnitPriceCents;

    const grossCents = Math.round(qty * baseUnitCostCents);
    let discountCents = toCents(raw.regularDiscountAmt ?? 0);

    if (
      (effectiveDiscountType === 'SENIOR_CITIZEN' ||
        effectiveDiscountType === 'PWD' ||
        effectiveDiscountType === 'NAAC' ||
        effectiveDiscountType === 'SOLO_PARENT') &&
      discountCents === 0
    ) {
      discountCents = Math.round(grossCents * 0.2);
      scPwdDiscountCents += discountCents;
    }

    const netSalesCents = Math.max(0, grossCents - discountCents);

    let vatCents = 0;
    if (sellerTaxType === 'VAT' && effectiveClassification === 'VATABLE') {
      vatCents = Math.round(netSalesCents * 0.12);
      vatableSalesCents += netSalesCents;
    } else if (effectiveClassification === 'ZERO_RATED') {
      zeroRatedSalesCents += netSalesCents;
    } else {
      vatExemptSalesCents += netSalesCents;
    }

    const atcDef = raw.atcCode
      ? birAtcCatalog[raw.atcCode.toUpperCase()]
      : undefined;
    const cwtRate = atcDef?.rate ?? 0;
    const cwtCents = cwtRate > 0 ? Math.round(netSalesCents * cwtRate) : 0;

    grossSalesCents += grossCents;
    totalDiscountCents += discountCents;
    netSalesTotalCents += netSalesCents;
    vatAmtTotalCents += vatCents;
    withholdingTaxCents += cwtCents;

    itemList.push({
      LineNo: index + 1,
      ItemCd:
        raw.itemCd && raw.itemCd.trim().length > 0
          ? raw.itemCd.trim()
          : `SKU-${(index + 1).toString().padStart(3, '0')}`,
      ItemNm: raw.itemNm.trim(),
      Unit: raw.unit && raw.unit.trim().length > 0 ? raw.unit.trim() : 'PCS',
      Qty: qty,
      UnitCost: fromCents(baseUnitCostCents),
      GrossAmt: fromCents(grossCents),
      DiscountType: effectiveDiscountType,
      DiscountAmt: fromCents(discountCents),
      NetSales: fromCents(netSalesCents),
      TaxClassification: effectiveClassification,
      VATAmt: fromCents(vatCents),
      AtcCode: atcDef?.code ?? null,
      CwtRate: cwtRate,
      CwtAmt: fromCents(cwtCents),
    });
  }

  const chargesCents = toCents(otherChargesAmt);
  const totalAmountDueCents =
    netSalesTotalCents +
    vatAmtTotalCents +
    chargesCents -
    withholdingTaxCents;

  return {
    itemList,
    summary: {
      GrossSalesAmt: fromCents(grossSalesCents),
      TotalDiscountAmt: fromCents(totalDiscountCents),
      ScPwdDiscountAmt: fromCents(scPwdDiscountCents),
      NetSales: fromCents(netSalesTotalCents),
      VATableSales: fromCents(vatableSalesCents),
      VATExemptSales: fromCents(vatExemptSalesCents),
      ZeroRatedSales: fromCents(zeroRatedSalesCents),
      VATAmt: fromCents(vatAmtTotalCents),
      WithholdingTaxAmt: fromCents(withholdingTaxCents),
      OtherChargesAmt: fromCents(chargesCents),
      TotalAmountDue: fromCents(totalAmountDueCents),
    },
  };
}

export function validateBirSchemaV201(payload: BirEisPayloadV201): string[] {
  const errors: string[] = [];

  if (payload.SchemaVer !== 'v2.01') {
    errors.push('SYN004: SchemaVer must be "v2.01".');
  }
  if (
    !/^\d{8}[A-Z0-9]{8}\d{8}$/.test(payload.EisUniqueId) ||
    payload.EisUniqueId.length !== 24
  ) {
    errors.push(
      `SYN004: EisUniqueId "${payload.EisUniqueId}" must be 24 characters (YYYYMMDD + 8-char CertId + 8-digit Seq).`,
    );
  }
  if (payload.CompInvoiceId.trim().length === 0) {
    errors.push('SYN004: CompInvoiceId is mandatory.');
  }
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/.test(payload.IssueDtm)) {
    errors.push('SYN004: IssueDtm must follow YYYY-MM-DDTHH:mm:ss format.');
  }
  if (payload.Currency !== 'PHP') {
    errors.push('SYN004: Currency must be PHP for BIR EIS.');
  }
  if (!/^\d{9}$/.test(payload.Seller.TIN)) {
    errors.push('SYN004: Seller.TIN must be exactly 9 numeric digits.');
  }
  if (!/^\d{4}$/.test(payload.Seller.BranchCd)) {
    errors.push('SYN004: Seller.BranchCd must be 4 numeric digits.');
  }
  if (payload.Seller.RegNm.trim().length === 0) {
    errors.push('SYN004: Seller.RegNm is mandatory.');
  }
  if (
    payload.TransClass === 'B2B' &&
    (!payload.Buyer.TIN || !/^\d{9}$/.test(payload.Buyer.TIN))
  ) {
    errors.push(
      'SYN004: Buyer.TIN (9 digits) is mandatory for B2B transactions under RR 7-2024.',
    );
  }
  if (payload.Buyer.RegNm.trim().length === 0) {
    errors.push('SYN004: Buyer.RegNm is mandatory.');
  }
  if (
    payload.CorrYN === 'Y' &&
    (!payload.RefEisUniqueId || payload.RefEisUniqueId.length === 0)
  ) {
    errors.push(
      'SYN004: RefEisUniqueId is required when CorrYN is "Y" (Credit/Debit Memo).',
    );
  }
  if (payload.ItemList.length === 0) {
    errors.push('SYN004: ItemList must contain at least one line item.');
  }
  for (const item of payload.ItemList) {
    if (item.ItemNm.trim().length === 0) {
      errors.push(`SYN004: ItemList[${item.LineNo}].ItemNm is mandatory.`);
    }
    if (item.Qty <= 0) {
      errors.push(`SYN004: ItemList[${item.LineNo}].Qty must be greater than 0.`);
    }
  }

  return errors;
}

export function validateBirArithmetic(payload: BirEisPayloadV201): string[] {
  const errors: string[] = [];
  const s = payload.Summary;

  const lineNetCents = payload.ItemList.reduce(
    (acc, i) => acc + toCents(i.NetSales),
    0,
  );
  const lineVatCents = payload.ItemList.reduce(
    (acc, i) => acc + toCents(i.VATAmt),
    0,
  );
  const lineCwtCents = payload.ItemList.reduce(
    (acc, i) => acc + toCents(i.CwtAmt),
    0,
  );

  if (Math.abs(lineNetCents - toCents(s.NetSales)) > 2) {
    errors.push(
      `VAL001: Summary.NetSales (${s.NetSales}) does not match sum of ItemList.NetSales (${fromCents(lineNetCents)}).`,
    );
  }
  if (Math.abs(lineVatCents - toCents(s.VATAmt)) > 2) {
    errors.push(
      `VAL001: Summary.VATAmt (${s.VATAmt}) does not match sum of ItemList.VATAmt (${fromCents(lineVatCents)}).`,
    );
  }
  if (payload.Seller.Type === 'VAT') {
    const expectedVatCents = Math.round(toCents(s.VATableSales) * 0.12);
    if (Math.abs(expectedVatCents - toCents(s.VATAmt)) > 5) {
      errors.push(
        `VAL001: Summary.VATAmt (${s.VATAmt}) deviates from 12% of VATableSales (${fromCents(expectedVatCents)}).`,
      );
    }
  }
  if (Math.abs(lineCwtCents - toCents(s.WithholdingTaxAmt)) > 2) {
    errors.push(
      `VAL001: Summary.WithholdingTaxAmt (${s.WithholdingTaxAmt}) does not match line CWT sum (${fromCents(lineCwtCents)}).`,
    );
  }
  const bucketCents =
    toCents(s.VATableSales) +
    toCents(s.VATExemptSales) +
    toCents(s.ZeroRatedSales);
  if (Math.abs(bucketCents - toCents(s.NetSales)) > 2) {
    errors.push(
      `VAL001: VATableSales + VATExemptSales + ZeroRatedSales (${fromCents(bucketCents)}) must equal NetSales (${s.NetSales}).`,
    );
  }
  const expectedTotalDueCents =
    toCents(s.NetSales) +
    toCents(s.VATAmt) +
    toCents(s.OtherChargesAmt) -
    toCents(s.WithholdingTaxAmt);
  if (Math.abs(expectedTotalDueCents - toCents(s.TotalAmountDue)) > 2) {
    errors.push(
      `VAL001: Summary.TotalAmountDue (${s.TotalAmountDue}) does not equal NetSales + VATAmt + OtherChargesAmt - WithholdingTaxAmt (${fromCents(expectedTotalDueCents)}).`,
    );
  }

  return errors;
}
