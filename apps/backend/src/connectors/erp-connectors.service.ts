import {
  BuyerCategory,
  DocType,
  SourceSystem,
  SystemType,
  TaxClassification,
  TransClass,
  normalizeBranchCd,
  normalizeTin9,
} from '../domain/bir-eis-schema.js';
import { RawLineItemInput } from '../services/tax-calculator.service.js';

export interface CanonicalIngestInput {
  taxpayerId?: string;
  branchCd?: string;
  sourceSystem: SourceSystem;
  externalRefId?: string | null;
  compInvoiceId?: string;
  systemType?: SystemType;
  docType?: DocType;
  transClass?: TransClass;
  direction?: 'SALES' | 'PURCHASE';
  isPaid?: boolean;
  issueDtm?: string;
  corrYN?: 'Y' | 'N';
  refEisUniqueId?: string | null;
  buyerName: string;
  buyerTin?: string | null;
  buyerBranchCd?: string | null;
  buyerCategory?: BuyerCategory;
  osacaPwdId?: string | null;
  buyerAddress?: {
    Street: string;
    Barangay: string;
    City: string;
    Province: string;
    ZipCode: string;
  } | null;
  items: RawLineItemInput[];
  otherChargesAmt?: number;
}

export interface XeroInvoicePayload {
  InvoiceID: string;
  InvoiceNumber: string;
  Type: 'ACCREC' | 'ACCPAY';
  DateString?: string;
  Status?: string;
  Contact: {
    Name: string;
    TaxNumber?: string;
    Addresses?: Array<{ AddressLine1?: string; City?: string; Region?: string; PostalCode?: string }>;
  };
  LineItems: Array<{
    ItemCode?: string;
    Description: string;
    Quantity: number;
    UnitAmount: number;
    TaxType?: 'OUTPUT' | 'INPUT' | 'EXEMPTOUTPUT' | 'ZERORATEDOUTPUT' | 'NONE';
    DiscountAmount?: number;
    AtcCode?: string;
  }>;
}

export interface QuickBooksInvoicePayload {
  Id: string;
  DocNumber: string;
  TxnType?: 'Invoice' | 'CreditMemo' | 'Bill';
  TxnDate?: string;
  CustomerRef: { name: string; tin?: string; branchCd?: string };
  Line: Array<{
    Description: string;
    SalesItemLineDetail?: {
      ItemRef?: { name: string; value?: string };
      Qty: number;
      UnitPrice: number;
      TaxCodeRef?: { value: 'VAT12' | 'EXEMPT' | 'ZERO' };
      AtcCode?: string;
    };
  }>;
}

export interface OdooAccountMovePayload {
  id: number;
  name: string;
  move_type: 'out_invoice' | 'out_refund' | 'in_invoice';
  invoice_date?: string;
  partner_id: { name: string; vat?: string; street?: string; city?: string; zip?: string };
  invoice_line_ids: Array<{
    product_code?: string;
    name: string;
    quantity: number;
    price_unit: number;
    tax_ids?: Array<'VAT_12' | 'VAT_EXEMPT' | 'VAT_ZERO'>;
    l10n_ph_atc?: string;
  }>;
}

function mapXeroTaxType(taxType?: string): TaxClassification {
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

export function mapXeroToCanonical(xero: XeroInvoicePayload, taxpayerId?: string): CanonicalIngestInput {
  const tin = xero.Contact.TaxNumber ? normalizeTin9(xero.Contact.TaxNumber) : null;
  const addr = xero.Contact.Addresses?.[0];
  return {
    taxpayerId,
    sourceSystem: 'XERO',
    externalRefId: xero.InvoiceID,
    compInvoiceId: xero.InvoiceNumber,
    systemType: 'CAS',
    docType: '01',
    transClass: tin ? 'B2B' : 'B2C',
    direction: xero.Type === 'ACCPAY' ? 'PURCHASE' : 'SALES',
    isPaid: xero.Status === 'PAID',
    issueDtm: xero.DateString,
    buyerName: xero.Contact.Name,
    buyerTin: tin,
    buyerBranchCd: tin ? '0000' : null,
    buyerAddress: addr
      ? {
          Street: addr.AddressLine1 ?? 'N/A',
          Barangay: 'N/A',
          City: addr.City ?? 'Makati City',
          Province: addr.Region ?? 'Metro Manila',
          ZipCode: addr.PostalCode ?? '1200',
        }
      : null,
    items: xero.LineItems.map((li) => ({
      itemCd: li.ItemCode,
      itemNm: li.Description,
      qty: li.Quantity,
      unitPrice: li.UnitAmount,
      taxClassification: mapXeroTaxType(li.TaxType),
      regularDiscountAmt: li.DiscountAmount ?? 0,
      atcCode: li.AtcCode ?? null,
    })),
  };
}

export function mapQuickBooksToCanonical(
  qbo: QuickBooksInvoicePayload,
  taxpayerId?: string,
): CanonicalIngestInput {
  const tin = qbo.CustomerRef.tin ? normalizeTin9(qbo.CustomerRef.tin) : null;
  const docType: DocType = qbo.TxnType === 'CreditMemo' ? '03' : '01';
  return {
    taxpayerId,
    sourceSystem: 'QUICKBOOKS',
    externalRefId: qbo.Id,
    compInvoiceId: qbo.DocNumber,
    systemType: 'CAS',
    docType,
    transClass: tin ? 'B2B' : 'B2C',
    direction: qbo.TxnType === 'Bill' ? 'PURCHASE' : 'SALES',
    isPaid: false,
    issueDtm: qbo.TxnDate ? `${qbo.TxnDate}T12:00:00` : undefined,
    corrYN: docType === '03' ? 'Y' : 'N',
    buyerName: qbo.CustomerRef.name,
    buyerTin: tin,
    buyerBranchCd: tin ? normalizeBranchCd(qbo.CustomerRef.branchCd) : null,
    items: qbo.Line.filter((l) => l.SalesItemLineDetail).map((l) => {
      const detail = l.SalesItemLineDetail!;
      const taxCode = detail.TaxCodeRef?.value;
      const taxClassification: TaxClassification =
        taxCode === 'EXEMPT' ? 'VAT_EXEMPT' : taxCode === 'ZERO' ? 'ZERO_RATED' : 'VATABLE';
      return {
        itemCd: detail.ItemRef?.value,
        itemNm: l.Description || detail.ItemRef?.name || 'Service Item',
        qty: detail.Qty,
        unitPrice: detail.UnitPrice,
        taxClassification,
        atcCode: detail.AtcCode ?? null,
      };
    }),
  };
}

export function mapOdooToCanonical(
  odoo: OdooAccountMovePayload,
  taxpayerId?: string,
): CanonicalIngestInput {
  const tin = odoo.partner_id.vat ? normalizeTin9(odoo.partner_id.vat) : null;
  const docType: DocType = odoo.move_type === 'out_refund' ? '03' : '02';
  return {
    taxpayerId,
    sourceSystem: 'ODOO',
    externalRefId: String(odoo.id),
    compInvoiceId: odoo.name,
    systemType: 'CAS',
    docType,
    transClass: tin ? 'B2B' : 'B2C',
    direction: odoo.move_type === 'in_invoice' ? 'PURCHASE' : 'SALES',
    isPaid: false,
    issueDtm: odoo.invoice_date ? `${odoo.invoice_date}T12:00:00` : undefined,
    corrYN: docType === '03' ? 'Y' : 'N',
    buyerName: odoo.partner_id.name,
    buyerTin: tin,
    buyerBranchCd: tin ? '0000' : null,
    buyerAddress: odoo.partner_id.street
      ? {
          Street: odoo.partner_id.street,
          Barangay: 'N/A',
          City: odoo.partner_id.city ?? 'Taguig City',
          Province: 'Metro Manila',
          ZipCode: odoo.partner_id.zip ?? '1634',
        }
      : null,
    items: odoo.invoice_line_ids.map((line) => {
      const taxTag = line.tax_ids?.[0] ?? 'VAT_12';
      const taxClassification: TaxClassification =
        taxTag === 'VAT_EXEMPT'
          ? 'VAT_EXEMPT'
          : taxTag === 'VAT_ZERO'
            ? 'ZERO_RATED'
            : 'VATABLE';
      return {
        itemCd: line.product_code,
        itemNm: line.name,
        qty: line.quantity,
        unitPrice: line.price_unit,
        taxClassification,
        atcCode: line.l10n_ph_atc ?? null,
      };
    }),
  };
}

/**
 * Parses a CSV batch string with header:
 * CompInvoiceId,BuyerName,BuyerTin,DocType,TransClass,ItemNm,Qty,UnitPrice,TaxClassification,AtcCode
 */
export function parseCsvBatchToCanonical(
  csvText: string,
  taxpayerId?: string,
): CanonicalIngestInput[] {
  const lines = csvText
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);
  if (lines.length < 2) {
    return [];
  }
  const rows = lines.slice(1);
  const grouped = new Map<string, CanonicalIngestInput>();

  for (const row of rows) {
    const cols = row.split(',').map((c) => c.trim().replace(/^"|"$/g, ''));
    const [
      compInvoiceId,
      buyerName,
      buyerTin,
      docTypeRaw,
      transClassRaw,
      itemNm,
      qtyRaw,
      unitPriceRaw,
      taxClassRaw,
      atcRaw,
    ] = cols;

    if (!compInvoiceId || !buyerName || !itemNm) continue;

    const existing = grouped.get(compInvoiceId);
    const tin = buyerTin ? normalizeTin9(buyerTin) : null;
    const item: RawLineItemInput = {
      itemNm,
      qty: Number(qtyRaw) || 1,
      unitPrice: Number(unitPriceRaw) || 0,
      taxClassification: (taxClassRaw as TaxClassification) || 'VATABLE',
      atcCode: atcRaw || null,
    };

    if (existing) {
      existing.items.push(item);
    } else {
      grouped.set(compInvoiceId, {
        taxpayerId,
        sourceSystem: 'CSV_BATCH',
        compInvoiceId,
        systemType: 'CAS',
        docType: (docTypeRaw as DocType) || '01',
        transClass: (transClassRaw as TransClass) || (tin ? 'B2B' : 'B2C'),
        buyerName,
        buyerTin: tin,
        buyerBranchCd: tin ? '0000' : null,
        items: [item],
      });
    }
  }

  return Array.from(grouped.values());
}
