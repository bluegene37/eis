// Gene - Nov, 24, 2026: Xero, QuickBooks Online, Odoo (l10n_ph), and CSV batch mappers
// into canonical BIR EIS v2.01 ingest inputs.
import {
  type CanonicalIngestInput,
  normalizeBranchCd,
  normalizeTin9,
  type RawLineItemInput,
} from './bir_tax.ts';

function mapXeroTaxType(taxType?: string | null): string {
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

export function mapXeroToCanonical(
  xero: Record<string, unknown>,
  taxpayerId?: string | null,
): CanonicalIngestInput {
  const contact = (xero['Contact'] as Record<string, unknown> | undefined) ?? {};
  const rawTin = contact['TaxNumber'] != null ? String(contact['TaxNumber']) : '';
  const tin = rawTin.length > 0 ? normalizeTin9(rawTin) : null;
  const addrs = Array.isArray(contact['Addresses']) ? contact['Addresses'] : [];
  const addr = addrs.length > 0 ? (addrs[0] as Record<string, unknown>) : null;
  const lineItems = Array.isArray(xero['LineItems']) ? xero['LineItems'] : [];

  return {
    taxpayerId: taxpayerId ?? null,
    sourceSystem: 'XERO',
    externalRefId: xero['InvoiceID'] != null ? String(xero['InvoiceID']) : null,
    compInvoiceId:
      xero['InvoiceNumber'] != null ? String(xero['InvoiceNumber']) : null,
    systemType: 'CAS',
    docType: '01',
    transClass: tin ? 'B2B' : 'B2C',
    direction: xero['Type'] === 'ACCPAY' ? 'PURCHASE' : 'SALES',
    isPaid: xero['Status'] === 'PAID',
    issueDtm: xero['DateString'] != null ? String(xero['DateString']) : null,
    buyerName: String(contact['Name'] ?? 'Xero Contact'),
    buyerTin: tin,
    buyerBranchCd: tin ? '0000' : null,
    buyerCategory: 'REGULAR',
    buyerAddress: addr
      ? {
          Street: String(addr['AddressLine1'] ?? 'N/A'),
          Barangay: 'N/A',
          City: String(addr['City'] ?? 'Makati City'),
          Province: String(addr['Region'] ?? 'Metro Manila'),
          ZipCode: String(addr['PostalCode'] ?? '1200'),
        }
      : null,
    items: lineItems.map((entry) => {
      const li = (entry ?? {}) as Record<string, unknown>;
      return {
        itemCd: li['ItemCode'] != null ? String(li['ItemCode']) : null,
        itemNm: String(li['Description'] ?? 'Item'),
        qty: Number(li['Quantity'] ?? 1),
        unitPrice: Number(li['UnitAmount'] ?? 0),
        taxClassification: mapXeroTaxType(
          li['TaxType'] != null ? String(li['TaxType']) : null,
        ),
        regularDiscountAmt: Number(li['DiscountAmount'] ?? 0),
        atcCode: li['AtcCode'] != null ? String(li['AtcCode']) : null,
      };
    }),
    otherChargesAmt: 0,
  };
}

export function mapQuickBooksToCanonical(
  qbo: Record<string, unknown>,
  taxpayerId?: string | null,
): CanonicalIngestInput {
  const cust =
    (qbo['CustomerRef'] as Record<string, unknown> | undefined) ?? {};
  const rawTin = cust['tin'] != null ? String(cust['tin']) : '';
  const tin = rawTin.length > 0 ? normalizeTin9(rawTin) : null;
  const txnType = qbo['TxnType'] != null ? String(qbo['TxnType']) : null;
  const docType = txnType === 'CreditMemo' ? '03' : '01';
  const lines = Array.isArray(qbo['Line']) ? qbo['Line'] : [];

  return {
    taxpayerId: taxpayerId ?? null,
    sourceSystem: 'QUICKBOOKS',
    externalRefId: qbo['Id'] != null ? String(qbo['Id']) : null,
    compInvoiceId: qbo['DocNumber'] != null ? String(qbo['DocNumber']) : null,
    systemType: 'CAS',
    docType,
    transClass: tin ? 'B2B' : 'B2C',
    direction: txnType === 'Bill' ? 'PURCHASE' : 'SALES',
    isPaid: false,
    issueDtm: qbo['TxnDate'] != null ? `${qbo['TxnDate']}T12:00:00` : null,
    corrYN: docType === '03' ? 'Y' : 'N',
    buyerName: String(cust['name'] ?? 'QuickBooks Customer'),
    buyerTin: tin,
    buyerBranchCd: tin
      ? normalizeBranchCd(
          cust['branchCd'] != null ? String(cust['branchCd']) : null,
        )
      : null,
    buyerCategory: 'REGULAR',
    items: lines
      .filter(
        (l) =>
          l &&
          typeof l === 'object' &&
          (l as Record<string, unknown>)['SalesItemLineDetail'] != null,
      )
      .map((l) => {
        const lineMap = l as Record<string, unknown>;
        const detail = lineMap['SalesItemLineDetail'] as Record<
          string,
          unknown
        >;
        const taxCodeRef = detail['TaxCodeRef'] as
          | Record<string, unknown>
          | undefined;
        const taxCode =
          taxCodeRef?.['value'] != null ? String(taxCodeRef['value']) : '';
        const taxClassification =
          taxCode === 'EXEMPT'
            ? 'VAT_EXEMPT'
            : taxCode === 'ZERO'
            ? 'ZERO_RATED'
            : 'VATABLE';
        const itemRef = detail['ItemRef'] as
          | Record<string, unknown>
          | undefined;
        return {
          itemCd:
            itemRef?.['value'] != null ? String(itemRef['value']) : null,
          itemNm: String(
            lineMap['Description'] ?? itemRef?.['name'] ?? 'Service Item',
          ),
          qty: Number(detail['Qty'] ?? 1),
          unitPrice: Number(detail['UnitPrice'] ?? 0),
          taxClassification,
          atcCode:
            detail['AtcCode'] != null ? String(detail['AtcCode']) : null,
        };
      }),
    otherChargesAmt: 0,
  };
}

export function mapOdooToCanonical(
  odoo: Record<string, unknown>,
  taxpayerId?: string | null,
): CanonicalIngestInput {
  const partner =
    (odoo['partner_id'] as Record<string, unknown> | undefined) ?? {};
  const rawTin = partner['vat'] != null ? String(partner['vat']) : '';
  const tin = rawTin.length > 0 ? normalizeTin9(rawTin) : null;
  const moveType = String(odoo['move_type'] ?? 'out_invoice');
  const docType = moveType === 'out_refund' ? '03' : '02';
  const lines = Array.isArray(odoo['invoice_line_ids'])
    ? odoo['invoice_line_ids']
    : [];

  return {
    taxpayerId: taxpayerId ?? null,
    sourceSystem: 'ODOO',
    externalRefId: odoo['id'] != null ? String(odoo['id']) : null,
    compInvoiceId: odoo['name'] != null ? String(odoo['name']) : null,
    systemType: 'CAS',
    docType,
    transClass: tin ? 'B2B' : 'B2C',
    direction: moveType === 'in_invoice' ? 'PURCHASE' : 'SALES',
    isPaid: false,
    issueDtm:
      odoo['invoice_date'] != null
        ? `${odoo['invoice_date']}T12:00:00`
        : null,
    corrYN: docType === '03' ? 'Y' : 'N',
    buyerName: String(partner['name'] ?? 'Odoo Partner'),
    buyerTin: tin,
    buyerBranchCd: tin ? '0000' : null,
    buyerCategory: 'REGULAR',
    buyerAddress:
      partner['street'] != null
        ? {
            Street: String(partner['street']),
            Barangay: 'N/A',
            City: String(partner['city'] ?? 'Taguig City'),
            Province: 'Metro Manila',
            ZipCode: String(partner['zip'] ?? '1634'),
          }
        : null,
    items: lines.map((l) => {
      const line = (l ?? {}) as Record<string, unknown>;
      const taxIds = Array.isArray(line['tax_ids'])
        ? line['tax_ids']
        : ['VAT_12'];
      const tag = taxIds.length > 0 ? String(taxIds[0]) : 'VAT_12';
      const taxClassification =
        tag === 'VAT_EXEMPT'
          ? 'VAT_EXEMPT'
          : tag === 'VAT_ZERO'
          ? 'ZERO_RATED'
          : 'VATABLE';
      return {
        itemCd:
          line['product_code'] != null ? String(line['product_code']) : null,
        itemNm: String(line['name'] ?? 'Odoo Line'),
        qty: Number(line['quantity'] ?? 1),
        unitPrice: Number(line['price_unit'] ?? 0),
        taxClassification,
        atcCode:
          line['l10n_ph_atc'] != null ? String(line['l10n_ph_atc']) : null,
      };
    }),
    otherChargesAmt: 0,
  };
}

export function parseCsvBatchToCanonical(
  csvText: string,
  taxpayerId?: string | null,
): CanonicalIngestInput[] {
  const lines = csvText
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);
  if (lines.length < 2) return [];

  const grouped = new Map<string, RawLineItemInput[]>();
  const headers = new Map<string, CanonicalIngestInput>();

  for (const row of lines.slice(1)) {
    const cols = row
      .split(',')
      .map((c) => c.trim().replace(/^"|"$/g, ''));
    if (cols.length < 8) continue;

    const compInvoiceId = cols[0];
    const buyerName = cols[1];
    const buyerTinRaw = cols[2];
    const docType = cols[3].length > 0 ? cols[3] : '01';
    const transClass = cols[4];
    const itemNm = cols[5];
    const qty = Number.parseFloat(cols[6]) || 1.0;
    const unitPrice = Number.parseFloat(cols[7]) || 0.0;
    const taxClass =
      cols.length > 8 && cols[8].length > 0 ? cols[8] : 'VATABLE';
    const atcCode = cols.length > 9 && cols[9].length > 0 ? cols[9] : null;

    if (!compInvoiceId || !buyerName || !itemNm) continue;

    const tin = buyerTinRaw.length > 0 ? normalizeTin9(buyerTinRaw) : null;
    const item: RawLineItemInput = {
      itemNm,
      qty,
      unitPrice,
      taxClassification: taxClass,
      atcCode,
    };

    if (!grouped.has(compInvoiceId)) grouped.set(compInvoiceId, []);
    grouped.get(compInvoiceId)!.push(item);

    if (!headers.has(compInvoiceId)) {
      headers.set(compInvoiceId, {
        taxpayerId: taxpayerId ?? null,
        sourceSystem: 'CSV_BATCH',
        compInvoiceId,
        systemType: 'CAS',
        docType,
        transClass:
          transClass.length > 0 ? transClass : tin ? 'B2B' : 'B2C',
        direction: 'SALES',
        isPaid: false,
        buyerName,
        buyerTin: tin,
        buyerBranchCd: tin ? '0000' : null,
        buyerCategory: 'REGULAR',
        items: grouped.get(compInvoiceId)!,
        otherChargesAmt: 0,
      });
    }
  }

  return Array.from(headers.values());
}
