/**
 * BIR Electronic Invoicing System (EIS) JSON Schema v2.01 & Canonical Tax Domain Types
 * Aligned with:
 *  - BIR EIS JSON Technical Specification v2.01 (CAS & CRM/POS variants)
 *  - RA 11976 (Ease of Paying Taxes / EOPT Act) & RR No. 7-2024
 *  - RR No. 11-2025 & RR No. 26-2025 (EIS Mandatory Transmission)
 *  - RR No. 6-2026 (Creditable Withholding Tax / CWT)
 */

export type SystemType = 'CAS' | 'POS';
export type DocType = '01' | '02' | '03' | '04'; // 01: Sales Invoice, 02: Service Invoice, 03: Credit Memo, 04: Debit Memo
export type TransClass = 'B2B' | 'B2C' | 'EXPORT' | 'GOVT';
export type TaxType = 'VAT' | 'NON_VAT';
export type TaxClassification = 'VATABLE' | 'VAT_EXEMPT' | 'ZERO_RATED';
export type BuyerCategory =
  | 'REGULAR'
  | 'SENIOR_CITIZEN'
  | 'PWD'
  | 'NAAC'
  | 'SOLO_PARENT'
  | 'DIPLOMAT';

export type DiscountType =
  | 'NONE'
  | 'REGULAR'
  | 'SENIOR_CITIZEN'
  | 'PWD'
  | 'NAAC'
  | 'SOLO_PARENT'
  | 'DIPLOMAT';

export type SourceSystem =
  | 'IES_UI'
  | 'XERO'
  | 'QUICKBOOKS'
  | 'ODOO'
  | 'CSV_BATCH'
  | 'WEBHOOK';

export type BirGatewayMode =
  | 'MOCK_BIR_SIMULATOR'
  | 'BIR_CERT_SANDBOX'
  | 'BIR_PRODUCTION';

export type TransmissionStatus =
  | 'DRAFT'
  | 'QUEUED_RETRY'
  | 'TRANSMITTED'
  | 'REJECTED';

export interface BirAddress {
  Street: string;
  Barangay: string;
  City: string;
  Province: string;
  ZipCode: string;
}

export interface SellerInfo {
  TIN: string; // 9 digits (normalized without dashes)
  BranchCd: string; // 4 digits, e.g., "0000" Head Office
  Type: TaxType;
  RegNm: string;
  BusinessNm: string;
  Address: BirAddress;
  Email: string;
}

export interface BuyerInfo {
  TIN: string | null; // Mandatory for B2B or >= EOPT threshold; nullable for B2C under threshold
  BranchCd: string | null;
  RegNm: string;
  Address: BirAddress | null;
  BuyerCategory: BuyerCategory;
  OsacaPwdId: string | null;
}

export interface BirEisItem {
  LineNo: number;
  ItemCd: string;
  ItemNm: string;
  Unit: string;
  Qty: number;
  UnitCost: number;
  GrossAmt: number;
  DiscountType: DiscountType;
  DiscountAmt: number;
  NetSales: number;
  TaxClassification: TaxClassification;
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
  SchemaVer: 'v2.01';
  SystemType: SystemType;
  EisUniqueId: string; // 24 chars: YYYYMMDD(8) + EisCertId(8) + Sequence(8)
  CompInvoiceId: string;
  IssueDtm: string; // YYYY-MM-DDTHH:mm:ss
  DocType: DocType;
  TransClass: TransClass;
  CorrYN: 'Y' | 'N';
  RefEisUniqueId: string | null;
  Currency: 'PHP';
  Seller: SellerInfo;
  Buyer: BuyerInfo;
  ItemList: BirEisItem[];
  Summary: BirEisSummary;
}

export interface TaxpayerBranch {
  branchCd: string;
  branchName: string;
  address: BirAddress;
  lastSequence: number;
  invoicePrefix: string;
}

export interface TaxpayerProfile {
  id: string;
  workspaceId: string;
  tin: string; // 9 digits
  taxType: TaxType;
  registeredName: string;
  businessName: string;
  email: string;
  eisCertId: string; // 8 chars
  pttNumber: string;
  publicKeyPem: string;
  privateKeyPem: string;
  aesKeyHex: string; // 32 bytes = 64 hex chars
  keyId: string;
  branches: TaxpayerBranch[];
  createdAt: string;
}

export interface BirGatewayReceipt {
  ackCode: 'ACK-200' | 'SYN004' | 'VAL001' | 'DUP001' | 'SEC001' | 'NET503';
  accepted: boolean;
  birAckId: string | null;
  message: string;
  errors: string[];
  gatewayTier: BirGatewayMode;
  processedAt: string;
  jwsThumbprint: string;
}

export interface StoredInvoiceRecord {
  id: string;
  taxpayerId: string;
  branchCd: string;
  sourceSystem: SourceSystem;
  externalRefId: string | null;
  direction: 'SALES' | 'PURCHASE';
  isPaid: boolean;
  payload: BirEisPayloadV201;
  jwsToken: string;
  aesEnvelope: {
    algorithm: 'AES-256-GCM';
    ivHex: string;
    authTagHex: string;
    ciphertextBase64: string;
    sha256Digest: string;
  };
  status: TransmissionStatus;
  retryCount: number;
  nextRetryAt: string | null;
  threeDayDeadlineAt: string;
  lastReceipt: BirGatewayReceipt | null;
  createdAt: string;
}

/** Normalize Philippine TIN to 9 digits (stripping dashes/branch suffix if provided). */
export function normalizeTin9(rawTin: string): string {
  const digits = rawTin.replace(/\D/g, '');
  if (digits.length >= 9) {
    return digits.slice(0, 9);
  }
  return digits.padStart(9, '0');
}

/** Normalize 4-digit BIR Branch Code (e.g., "0000" for Head Office). */
export function normalizeBranchCd(rawBranch?: string | null): string {
  const digits = (rawBranch ?? '0000').replace(/\D/g, '');
  return digits.slice(0, 4).padStart(4, '0');
}

/**
 * Generates the mandatory 24-character BIR EIS EisUniqueId:
 *   YYYYMMDD (8) + EisCertId (8) + Zero-padded Sequential Control (8)
 */
export function buildEisUniqueId(
  issueDate: Date,
  eisCertId: string,
  sequenceNumber: number,
): string {
  const yyyy = issueDate.getFullYear().toString();
  const mm = String(issueDate.getMonth() + 1).padStart(2, '0');
  const dd = String(issueDate.getDate()).padStart(2, '0');
  const cert = eisCertId.replace(/[^A-Za-z0-9]/g, '').toUpperCase().padEnd(8, '0').slice(0, 8);
  const seq = String(sequenceNumber).padStart(8, '0').slice(-8);
  return `${yyyy}${mm}${dd}${cert}${seq}`;
}

export function formatBirDateTime(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

/** Validates structural completeness of a BIR EIS v2.01 payload (mirrors SYN004 checks). */
export function validateBirSchemaV201(payload: BirEisPayloadV201): string[] {
  const errors: string[] = [];

  if (payload.SchemaVer !== 'v2.01') {
    errors.push('SYN004: SchemaVer must be "v2.01".');
  }
  if (!/^\d{8}[A-Z0-9]{8}\d{8}$/.test(payload.EisUniqueId) || payload.EisUniqueId.length !== 24) {
    errors.push(`SYN004: EisUniqueId "${payload.EisUniqueId}" must be 24 characters (YYYYMMDD + 8-char CertId + 8-digit Seq).`);
  }
  if (!payload.CompInvoiceId || payload.CompInvoiceId.trim().length === 0) {
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
  if (!payload.Seller.RegNm?.trim()) {
    errors.push('SYN004: Seller.RegNm is mandatory.');
  }
  if (payload.TransClass === 'B2B' && (!payload.Buyer.TIN || !/^\d{9}$/.test(payload.Buyer.TIN))) {
    errors.push('SYN004: Buyer.TIN (9 digits) is mandatory for B2B transactions under RR 7-2024.');
  }
  if (!payload.Buyer.RegNm?.trim()) {
    errors.push('SYN004: Buyer.RegNm is mandatory.');
  }
  if (payload.CorrYN === 'Y' && !payload.RefEisUniqueId) {
    errors.push('SYN004: RefEisUniqueId is required when CorrYN is "Y" (Credit/Debit Memo).');
  }
  if (!Array.isArray(payload.ItemList) || payload.ItemList.length === 0) {
    errors.push('SYN004: ItemList must contain at least one line item.');
  }
  for (const item of payload.ItemList) {
    if (!item.ItemNm?.trim()) {
      errors.push(`SYN004: ItemList[${item.LineNo}].ItemNm is mandatory.`);
    }
    if (item.Qty <= 0) {
      errors.push(`SYN004: ItemList[${item.LineNo}].Qty must be greater than 0.`);
    }
  }

  return errors;
}
