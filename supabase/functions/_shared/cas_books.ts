// Gene - Nov, 24, 2026: PFRS Chart of Accounts & BIR CAS 6 Mandatory Books double-entry generator
// using exact integer-centavo accounting math.
import { type BirEisPayloadV201, fromCents, toCents } from './bir_tax.ts';

export interface ChartOfAccountItem {
  code: string;
  name: string;
  category: string;
  normalBalance: string;
}

export const pfrsChartOfAccounts: ChartOfAccountItem[] = [
  { code: '1010', name: 'Cash on Hand and in Banks', category: 'ASSET', normalBalance: 'DEBIT' },
  { code: '1110', name: 'Accounts Receivable - Trade', category: 'ASSET', normalBalance: 'DEBIT' },
  { code: '1150', name: 'Creditable Withholding Tax (BIR 2307)', category: 'ASSET', normalBalance: 'DEBIT' },
  { code: '1160', name: 'Input VAT Receivable', category: 'ASSET', normalBalance: 'DEBIT' },
  { code: '2010', name: 'Accounts Payable - Trade', category: 'LIABILITY', normalBalance: 'CREDIT' },
  { code: '2110', name: 'Output VAT Payable', category: 'LIABILITY', normalBalance: 'CREDIT' },
  { code: '2120', name: 'Expanded Withholding Tax Payable (1601-EQ)', category: 'LIABILITY', normalBalance: 'CREDIT' },
  { code: '4010', name: 'Sales Revenue - Goods', category: 'REVENUE', normalBalance: 'CREDIT' },
  { code: '4020', name: 'Service Revenue', category: 'REVENUE', normalBalance: 'CREDIT' },
  { code: '4050', name: 'Sales Discounts (Regular / SC / PWD)', category: 'REVENUE', normalBalance: 'DEBIT' },
  { code: '4060', name: 'Sales Returns & Allowances (Credit Memo)', category: 'REVENUE', normalBalance: 'DEBIT' },
  { code: '5010', name: 'Purchases / Cost of Goods & Services', category: 'EXPENSE', normalBalance: 'DEBIT' },
  { code: '6010', name: 'Operating & Professional Expenses', category: 'EXPENSE', normalBalance: 'DEBIT' },
];

const coaMap = new Map(pfrsChartOfAccounts.map((a) => [a.code, a]));

export interface JournalLineDraft {
  accountCode: string;
  accountName: string;
  debit: number;
  credit: number;
}

export interface CasJournalEntryDraft {
  bookType: 'GJ' | 'GL' | 'SJ' | 'PJ' | 'CRJ' | 'CDJ';
  entryDate: string;
  referenceNo: string;
  eisUniqueId: string;
  counterpartyName: string;
  counterpartyTin: string | null;
  particulars: string;
  lines: JournalLineDraft[];
  totalDebit: number;
  totalCredit: number;
}

function makeLine(
  accountCode: string,
  debitCents: number,
  creditCents: number,
): JournalLineDraft {
  const acct = coaMap.get(accountCode);
  return {
    accountCode,
    accountName: acct?.name ?? `Account ${accountCode}`,
    debit: fromCents(debitCents),
    credit: fromCents(creditCents),
  };
}

function buildEntry(params: {
  bookType: CasJournalEntryDraft['bookType'];
  entryDate: string;
  referenceNo: string;
  eisUniqueId: string;
  counterpartyName: string;
  counterpartyTin: string | null;
  particulars: string;
  lines: JournalLineDraft[];
}): CasJournalEntryDraft {
  const filtered = params.lines.filter((l) => l.debit !== 0 || l.credit !== 0);
  const totalDebitCents = filtered.reduce((acc, l) => acc + toCents(l.debit), 0);
  const totalCreditCents = filtered.reduce((acc, l) => acc + toCents(l.credit), 0);
  if (totalDebitCents !== totalCreditCents) {
    throw new Error(
      `Unbalanced CAS journal entry (${params.referenceNo}): debit=${fromCents(totalDebitCents)}, credit=${fromCents(totalCreditCents)}`,
    );
  }
  return {
    bookType: params.bookType,
    entryDate: params.entryDate,
    referenceNo: params.referenceNo,
    eisUniqueId: params.eisUniqueId,
    counterpartyName: params.counterpartyName,
    counterpartyTin: params.counterpartyTin,
    particulars: params.particulars,
    lines: filtered,
    totalDebit: fromCents(totalDebitCents),
    totalCredit: fromCents(totalCreditCents),
  };
}

export function createJournalEntriesForInvoice(params: {
  direction: string;
  isPaid: boolean;
  sourceSystem: string;
  payload: BirEisPayloadV201;
}): CasJournalEntryDraft[] {
  const p = params.payload;
  const s = p.Summary;
  const entryDate = p.IssueDtm.slice(0, 10);
  const entries: CasJournalEntryDraft[] = [];

  const netSalesCents = toCents(s.NetSales);
  const vatCents = toCents(s.VATAmt);
  const cwtCents = toCents(s.WithholdingTaxAmt);
  const totalDueCents = toCents(s.TotalAmountDue);
  const discountCents = toCents(s.TotalDiscountAmt);
  const grossCents = toCents(s.GrossSalesAmt);
  const chargesCents = toCents(s.OtherChargesAmt);

  if (params.direction === 'SALES') {
    const isCreditMemo = p.DocType === '03';
    const revenueAcct = p.DocType === '02' ? '4020' : '4010';

    if (isCreditMemo) {
      const lines: JournalLineDraft[] = [];
      if (netSalesCents + chargesCents > 0) {
        lines.push(makeLine('4060', netSalesCents + chargesCents, 0));
      }
      if (vatCents > 0) lines.push(makeLine('2110', vatCents, 0));
      if (cwtCents > 0) lines.push(makeLine('1150', 0, cwtCents));
      lines.push(makeLine(params.isPaid ? '1010' : '1110', 0, totalDueCents));

      entries.push(
        buildEntry({
          bookType: 'GJ',
          entryDate,
          referenceNo: p.CompInvoiceId,
          eisUniqueId: p.EisUniqueId,
          counterpartyName: p.Buyer.RegNm,
          counterpartyTin: p.Buyer.TIN,
          particulars: `Credit Memo (${p.RefEisUniqueId ?? ''}) via ${params.sourceSystem}`,
          lines,
        }),
      );
      return entries;
    }

    const lines: JournalLineDraft[] = [
      makeLine(params.isPaid ? '1010' : '1110', totalDueCents, 0),
    ];
    if (cwtCents > 0) lines.push(makeLine('1150', cwtCents, 0));
    if (discountCents > 0) lines.push(makeLine('4050', discountCents, 0));
    if (grossCents + chargesCents > 0) {
      lines.push(makeLine(revenueAcct, 0, grossCents + chargesCents));
    }
    if (vatCents > 0) lines.push(makeLine('2110', 0, vatCents));

    entries.push(
      buildEntry({
        bookType: 'SJ',
        entryDate,
        referenceNo: p.CompInvoiceId,
        eisUniqueId: p.EisUniqueId,
        counterpartyName: p.Buyer.RegNm,
        counterpartyTin: p.Buyer.TIN,
        particulars: `BIR DocType ${p.DocType} (${p.TransClass}) via ${params.sourceSystem}`,
        lines,
      }),
    );

    if (params.isPaid && p.SystemType === 'POS') {
      entries.push(
        buildEntry({
          bookType: 'CRJ',
          entryDate,
          referenceNo: `OR-${p.CompInvoiceId}`,
          eisUniqueId: p.EisUniqueId,
          counterpartyName: p.Buyer.RegNm,
          counterpartyTin: p.Buyer.TIN,
          particulars: `Cash Receipt for POS Invoice ${p.CompInvoiceId}`,
          lines: [
            makeLine('1010', totalDueCents, 0),
            makeLine('1010', 0, totalDueCents),
          ],
        }),
      );
    }

    return entries;
  }

  const lines: JournalLineDraft[] = [
    makeLine('5010', netSalesCents + chargesCents, 0),
  ];
  if (vatCents > 0) lines.push(makeLine('1160', vatCents, 0));
  if (cwtCents > 0) lines.push(makeLine('2120', 0, cwtCents));
  lines.push(makeLine(params.isPaid ? '1010' : '2010', 0, totalDueCents));

  entries.push(
    buildEntry({
      bookType: params.isPaid ? 'CDJ' : 'PJ',
      entryDate,
      referenceNo: p.CompInvoiceId,
      eisUniqueId: p.EisUniqueId,
      counterpartyName: p.Seller.RegNm,
      counterpartyTin: p.Seller.TIN,
      particulars: `Purchase / Expense Bill via ${params.sourceSystem}`,
      lines,
    }),
  );

  return entries;
}
