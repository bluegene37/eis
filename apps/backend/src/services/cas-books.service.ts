import crypto from 'node:crypto';
import { StoredInvoiceRecord } from '../domain/bir-eis-schema.js';
import { round2 } from './tax-calculator.service.js';

export type BirBookType = 'GJ' | 'GL' | 'SJ' | 'PJ' | 'CRJ' | 'CDJ';

export interface ChartOfAccountItem {
  code: string;
  name: string;
  category: 'ASSET' | 'LIABILITY' | 'EQUITY' | 'REVENUE' | 'EXPENSE';
  normalBalance: 'DEBIT' | 'CREDIT';
}

export interface JournalLine {
  accountCode: string;
  accountName: string;
  debit: number;
  credit: number;
}

export interface CasJournalEntry {
  id: string;
  taxpayerId: string;
  branchCd: string;
  bookType: BirBookType;
  entryDate: string; // YYYY-MM-DD
  referenceNo: string; // CompInvoiceId
  eisUniqueId: string;
  counterpartyName: string;
  counterpartyTin: string | null;
  particulars: string;
  lines: JournalLine[];
  totalDebit: number;
  totalCredit: number;
  createdAt: string;
}

export interface TrialBalanceRow {
  accountCode: string;
  accountName: string;
  category: string;
  debitTotal: number;
  creditTotal: number;
  netBalance: number;
}

/**
 * PFRS / Philippine Standard Chart of Accounts tailored for BIR CAS (RR 9-2009).
 */
export const PFRS_CHART_OF_ACCOUNTS: ChartOfAccountItem[] = [
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

const COA_MAP = new Map(PFRS_CHART_OF_ACCOUNTS.map((a) => [a.code, a]));

function line(accountCode: string, debit: number, credit: number): JournalLine {
  const acct = COA_MAP.get(accountCode);
  return {
    accountCode,
    accountName: acct?.name ?? `Account ${accountCode}`,
    debit: round2(debit),
    credit: round2(credit),
  };
}

/**
 * Generates double-entry journal postings for the 6 Mandatory BIR Books of Accounts
 * under RR No. 9-2009:
 *   - Sales Journal (SJ) / Cash Receipts Journal (CRJ) for Sales & Service Invoices
 *   - Purchase Journal (PJ) / Cash Disbursements Journal (CDJ) for Vendor Bills
 *   - General Journal (GJ) for Credit/Debit Memo adjustments
 *   - General Ledger (GL) aggregates all entries across books
 */
export function createJournalEntriesForInvoice(record: StoredInvoiceRecord): CasJournalEntry[] {
  const p = record.payload;
  const s = p.Summary;
  const entryDate = p.IssueDtm.slice(0, 10);
  const nowIso = new Date().toISOString();
  const entries: CasJournalEntry[] = [];

  if (record.direction === 'SALES') {
    const isCreditMemo = p.DocType === '03';
    const revenueAcct = p.DocType === '02' ? '4020' : '4010';
    const lines: JournalLine[] = [];

    if (isCreditMemo) {
      // Credit Memo reverses revenue, Output VAT, and AR
      if (s.NetSales > 0) {
        lines.push(line('4060', s.NetSales, 0));
      }
      if (s.VATAmt > 0) {
        lines.push(line('2110', s.VATAmt, 0));
      }
      if (s.WithholdingTaxAmt > 0) {
        lines.push(line('1150', 0, s.WithholdingTaxAmt));
      }
      lines.push(line(record.isPaid ? '1010' : '1110', 0, s.TotalAmountDue));

      entries.push(
        buildEntry({
          taxpayerId: record.taxpayerId,
          branchCd: record.branchCd,
          bookType: 'GJ',
          entryDate,
          referenceNo: p.CompInvoiceId,
          eisUniqueId: p.EisUniqueId,
          counterpartyName: p.Buyer.RegNm,
          counterpartyTin: p.Buyer.TIN,
          particulars: `Credit Memo (${p.RefEisUniqueId ?? ''}) via ${record.sourceSystem}`,
          lines,
          createdAt: nowIso,
        }),
      );
      return entries;
    }

    // Standard Sales or Service Invoice -> Sales Journal (SJ)
    lines.push(line(record.isPaid ? '1010' : '1110', s.TotalAmountDue, 0));
    if (s.WithholdingTaxAmt > 0) {
      lines.push(line('1150', s.WithholdingTaxAmt, 0));
    }
    if (s.TotalDiscountAmt > 0) {
      lines.push(line('4050', s.TotalDiscountAmt, 0));
    }
    if (s.GrossSalesAmt + s.OtherChargesAmt > 0) {
      lines.push(line(revenueAcct, 0, round2(s.GrossSalesAmt + s.OtherChargesAmt)));
    }
    if (s.VATAmt > 0) {
      lines.push(line('2110', 0, s.VATAmt));
    }

    entries.push(
      buildEntry({
        taxpayerId: record.taxpayerId,
        branchCd: record.branchCd,
        bookType: 'SJ',
        entryDate,
        referenceNo: p.CompInvoiceId,
        eisUniqueId: p.EisUniqueId,
        counterpartyName: p.Buyer.RegNm,
        counterpartyTin: p.Buyer.TIN,
        particulars: `BIR DocType ${p.DocType} (${p.TransClass}) via ${record.sourceSystem}`,
        lines,
        createdAt: nowIso,
      }),
    );

    // If paid immediately (e.g. POS cash sale), also record collection transfer in Cash Receipts Journal (CRJ)
    if (record.isPaid && p.SystemType === 'POS') {
      entries.push(
        buildEntry({
          taxpayerId: record.taxpayerId,
          branchCd: record.branchCd,
          bookType: 'CRJ',
          entryDate,
          referenceNo: `OR-${p.CompInvoiceId}`,
          eisUniqueId: p.EisUniqueId,
          counterpartyName: p.Buyer.RegNm,
          counterpartyTin: p.Buyer.TIN,
          particulars: `Cash Receipt for POS Invoice ${p.CompInvoiceId}`,
          lines: [
            line('1010', s.TotalAmountDue, 0),
            line('1010', 0, s.TotalAmountDue),
          ],
          createdAt: nowIso,
        }),
      );
    }

    return entries;
  }

  // PURCHASE direction -> Purchase Journal (PJ) or Cash Disbursements Journal (CDJ)
  const lines: JournalLine[] = [];
  lines.push(line('5010', s.NetSales, 0));
  if (s.VATAmt > 0) {
    lines.push(line('1160', s.VATAmt, 0));
  }
  if (s.WithholdingTaxAmt > 0) {
    lines.push(line('2120', 0, s.WithholdingTaxAmt));
  }
  lines.push(line(record.isPaid ? '1010' : '2010', 0, s.TotalAmountDue));

  entries.push(
    buildEntry({
      taxpayerId: record.taxpayerId,
      branchCd: record.branchCd,
      bookType: record.isPaid ? 'CDJ' : 'PJ',
      entryDate,
      referenceNo: p.CompInvoiceId,
      eisUniqueId: p.EisUniqueId,
      counterpartyName: p.Seller.RegNm,
      counterpartyTin: p.Seller.TIN,
      particulars: `Purchase / Expense Bill via ${record.sourceSystem}`,
      lines,
      createdAt: nowIso,
    }),
  );

  return entries;
}

function buildEntry(params: Omit<CasJournalEntry, 'id' | 'totalDebit' | 'totalCredit'>): CasJournalEntry {
  const filteredLines = params.lines.filter((l) => l.debit !== 0 || l.credit !== 0);
  const totalDebit = round2(filteredLines.reduce((acc, l) => acc + l.debit, 0));
  const totalCredit = round2(filteredLines.reduce((acc, l) => acc + l.credit, 0));
  return {
    id: `JE-${crypto.randomUUID().slice(0, 8).toUpperCase()}`,
    ...params,
    lines: filteredLines,
    totalDebit,
    totalCredit,
  };
}

export function computeTrialBalance(entries: CasJournalEntry[]): {
  rows: TrialBalanceRow[];
  totalDebits: number;
  totalCredits: number;
  isBalanced: boolean;
} {
  const agg = new Map<string, { debit: number; credit: number }>();

  for (const entry of entries) {
    for (const ln of entry.lines) {
      const current = agg.get(ln.accountCode) ?? { debit: 0, credit: 0 };
      current.debit = round2(current.debit + ln.debit);
      current.credit = round2(current.credit + ln.credit);
      agg.set(ln.accountCode, current);
    }
  }

  const rows: TrialBalanceRow[] = [];
  let totalDebits = 0;
  let totalCredits = 0;

  for (const acct of PFRS_CHART_OF_ACCOUNTS) {
    const val = agg.get(acct.code);
    if (!val) continue;
    totalDebits = round2(totalDebits + val.debit);
    totalCredits = round2(totalCredits + val.credit);
    const netBalance =
      acct.normalBalance === 'DEBIT'
        ? round2(val.debit - val.credit)
        : round2(val.credit - val.debit);
    rows.push({
      accountCode: acct.code,
      accountName: acct.name,
      category: acct.category,
      debitTotal: val.debit,
      creditTotal: val.credit,
      netBalance,
    });
  }

  return {
    rows,
    totalDebits,
    totalCredits,
    isBalanced: Math.abs(totalDebits - totalCredits) <= 0.01,
  };
}
