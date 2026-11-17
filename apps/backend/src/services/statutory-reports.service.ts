import crypto from 'node:crypto';
import { StoredInvoiceRecord, TaxpayerProfile } from '../domain/bir-eis-schema.js';
import { round2 } from './tax-calculator.service.js';

export interface AuditTrailEntry {
  seq: number;
  id: string;
  timestamp: string;
  actor: string;
  action: string;
  taxpayerTin: string;
  entityType: string;
  entityId: string;
  details: string;
  prevHash: string;
  entryHash: string;
}

/**
 * Generates BIR RELIEF SLSP (Summary List of Sales or Purchases) in both
 * standard comma-delimited .DAT (H/D record layout) and .CSV formats.
 */
export function generateSlspReport(
  taxpayer: TaxpayerProfile,
  records: StoredInvoiceRecord[],
  kind: 'SALES' | 'PURCHASES',
  fiscalPeriod: string, // YYYYMM e.g. 202611
): { filename: string; datContent: string; csvContent: string; rowCount: number } {
  const filtered = records.filter((r) =>
    kind === 'SALES' ? r.direction === 'SALES' : r.direction === 'PURCHASE',
  );
  const headOffice = taxpayer.branches[0]?.address;
  const totalExempt = round2(filtered.reduce((s, r) => s + r.payload.Summary.VATExemptSales, 0));
  const totalZero = round2(filtered.reduce((s, r) => s + r.payload.Summary.ZeroRatedSales, 0));
  const totalVatable = round2(filtered.reduce((s, r) => s + r.payload.Summary.VATableSales, 0));
  const totalVat = round2(filtered.reduce((s, r) => s + r.payload.Summary.VATAmt, 0));

  const headerType = kind === 'SALES' ? 'H,S' : 'H,P';
  const detailType = kind === 'SALES' ? 'D,S' : 'D,P';

  const datLines: string[] = [
    [
      headerType,
      `"${taxpayer.tin}"`,
      `"${taxpayer.registeredName.replace(/"/g, '')}"`,
      `""`,
      `""`,
      `""`,
      `"${taxpayer.businessName.replace(/"/g, '')}"`,
      `"${headOffice?.Street ?? ''} ${headOffice?.Barangay ?? ''}"`,
      `"${headOffice?.City ?? ''} ${headOffice?.Province ?? ''}"`,
      totalExempt.toFixed(2),
      totalZero.toFixed(2),
      totalVatable.toFixed(2),
      totalVat.toFixed(2),
      `"009"`, // RDO code placeholder
      fiscalPeriod,
      12, // fiscal year end month
    ].join(','),
  ];

  const csvLines: string[] = [
    'TAXABLE_MONTH,TIN,REGISTERED_NAME,ADDRESS,EXEMPT_SALES,ZERO_RATED_SALES,TAXABLE_SALES,OUTPUT_INPUT_VAT,REFERENCE_INVOICE',
  ];

  for (const r of filtered) {
    const p = r.payload;
    const party = kind === 'SALES' ? p.Buyer : p.Seller;
    const partyTin = party.TIN ?? '000000000';
    const addr = party.Address
      ? `${party.Address.Street} ${party.Address.City}`.trim()
      : 'PHILIPPINES';

    datLines.push(
      [
        detailType,
        `"${partyTin}"`,
        `"${party.RegNm.replace(/"/g, '')}"`,
        `""`,
        `""`,
        `""`,
        `"${addr.replace(/"/g, '')}"`,
        `""`,
        p.Summary.VATExemptSales.toFixed(2),
        p.Summary.ZeroRatedSales.toFixed(2),
        p.Summary.VATableSales.toFixed(2),
        p.Summary.VATAmt.toFixed(2),
        `"${taxpayer.tin}"`,
        p.IssueDtm.slice(0, 7).replace('-', '') + '01',
      ].join(','),
    );

    csvLines.push(
      [
        p.IssueDtm.slice(0, 7),
        partyTin,
        `"${party.RegNm.replace(/"/g, '')}"`,
        `"${addr.replace(/"/g, '')}"`,
        p.Summary.VATExemptSales.toFixed(2),
        p.Summary.ZeroRatedSales.toFixed(2),
        p.Summary.VATableSales.toFixed(2),
        p.Summary.VATAmt.toFixed(2),
        p.CompInvoiceId,
      ].join(','),
    );
  }

  return {
    filename: `${taxpayer.tin}${kind === 'SALES' ? 'S' : 'P'}${fiscalPeriod}.DAT`,
    datContent: datLines.join('\n'),
    csvContent: csvLines.join('\n'),
    rowCount: filtered.length,
  };
}

/**
 * Generates BIR SAWT (Summary Alphalist of Withholding Taxes) or QAP (1601-EQ) .DAT export.
 */
export function generateWithholdingDatReport(
  taxpayer: TaxpayerProfile,
  records: StoredInvoiceRecord[],
  reportKind: 'SAWT' | 'QAP',
  periodQuarter: string, // YYYYMM e.g. 202612
): { filename: string; datContent: string; csvContent: string; rowCount: number } {
  const applicable = records.filter((r) => {
    const hasCwt = r.payload.Summary.WithholdingTaxAmt > 0;
    if (!hasCwt) return false;
    return reportKind === 'SAWT' ? r.direction === 'SALES' : r.direction === 'PURCHASE';
  });

  const formCode = reportKind === 'SAWT' ? '1702Q' : '1601EQ';
  const headerCode = reportKind === 'SAWT' ? 'HSAWT' : 'HQAP';
  const detailCode = reportKind === 'SAWT' ? 'DSAWT' : 'DQAP';

  const totalBase = round2(applicable.reduce((s, r) => s + r.payload.Summary.NetSales, 0));
  const totalTaxWithheld = round2(
    applicable.reduce((s, r) => s + r.payload.Summary.WithholdingTaxAmt, 0),
  );

  const datLines: string[] = [
    [
      headerCode,
      `H${formCode}`,
      taxpayer.tin,
      '0000',
      `"${taxpayer.registeredName.replace(/"/g, '')}"`,
      periodQuarter,
      '009',
    ].join(','),
  ];

  const csvLines: string[] = [
    'SEQ,COUNTERPARTY_TIN,BRANCH_CD,REGISTERED_NAME,ATC_CODE,TAX_BASE,TAX_RATE_PCT,TAX_WITHHELD,INVOICE_NO',
  ];

  applicable.forEach((r, idx) => {
    const p = r.payload;
    const party = reportKind === 'SAWT' ? p.Buyer : p.Seller;
    const atcItem = p.ItemList.find((i) => i.AtcCode);
    const atc = atcItem?.AtcCode ?? 'WC160';
    const ratePct = round2((atcItem?.CwtRate ?? 0.02) * 100);

    datLines.push(
      [
        detailCode,
        `D${formCode}`,
        idx + 1,
        party.TIN ?? '000000000',
        party.BranchCd ?? '0000',
        `"${party.RegNm.replace(/"/g, '')}"`,
        periodQuarter,
        atc,
        p.Summary.NetSales.toFixed(2),
        ratePct.toFixed(2),
        p.Summary.WithholdingTaxAmt.toFixed(2),
      ].join(','),
    );

    csvLines.push(
      [
        idx + 1,
        party.TIN ?? '000000000',
        party.BranchCd ?? '0000',
        `"${party.RegNm.replace(/"/g, '')}"`,
        atc,
        p.Summary.NetSales.toFixed(2),
        ratePct.toFixed(2),
        p.Summary.WithholdingTaxAmt.toFixed(2),
        p.CompInvoiceId,
      ].join(','),
    );
  });

  datLines.push(
    [
      reportKind === 'SAWT' ? 'CSAWT' : 'CQAP',
      `C${formCode}`,
      taxpayer.tin,
      '0000',
      periodQuarter,
      totalBase.toFixed(2),
      totalTaxWithheld.toFixed(2),
    ].join(','),
  );

  return {
    filename: `${taxpayer.tin}0000${periodQuarter}${formCode}.DAT`,
    datContent: datLines.join('\n'),
    csvContent: csvLines.join('\n'),
    rowCount: applicable.length,
  };
}

export interface BirForm2307Payload {
  formTitle: string;
  periodFrom: string;
  periodTo: string;
  payee: { tin: string; branchCd: string; name: string; address: string };
  payor: { tin: string; branchCd: string; name: string; address: string };
  referenceInvoice: string;
  eisUniqueId: string;
  lines: Array<{
    atcCode: string;
    description: string;
    month1Base: number;
    month2Base: number;
    month3Base: number;
    totalIncomePayment: number;
    taxRatePct: number;
    taxWithheld: number;
  }>;
  totalTaxWithheld: number;
  printableHtml: string;
}

export function generateBirForm2307(
  record: StoredInvoiceRecord,
): BirForm2307Payload {
  const p = record.payload;
  const issueDate = new Date(p.IssueDtm);
  const year = issueDate.getFullYear();
  const quarterIndex = Math.floor(issueDate.getMonth() / 3);
  const startMonth = quarterIndex * 3 + 1;
  const monthInQuarter = (issueDate.getMonth() % 3) + 1;

  const periodFrom = `${year}-${String(startMonth).padStart(2, '0')}-01`;
  const endMonth = startMonth + 2;
  const periodTo = `${year}-${String(endMonth).padStart(2, '0')}-${endMonth === 6 || endMonth === 9 ? '30' : '31'}`;

  const payee = record.direction === 'SALES' ? p.Seller : p.Seller;
  const payor = record.direction === 'SALES' ? p.Buyer : p.Buyer;

  const lines = p.ItemList.filter((i) => i.CwtAmt > 0).map((item) => ({
    atcCode: item.AtcCode ?? 'WC160',
    description: item.ItemNm,
    month1Base: monthInQuarter === 1 ? item.NetSales : 0,
    month2Base: monthInQuarter === 2 ? item.NetSales : 0,
    month3Base: monthInQuarter === 3 ? item.NetSales : 0,
    totalIncomePayment: item.NetSales,
    taxRatePct: round2(item.CwtRate * 100),
    taxWithheld: item.CwtAmt,
  }));

  const payeeAddr = `${payee.Address.Street}, ${payee.Address.City}, ${payee.Address.Province}`;
  const payorAddr = payor.Address
    ? `${payor.Address.Street}, ${payor.Address.City}, ${payor.Address.Province}`
    : 'Metro Manila, Philippines';

  const printableHtml = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>BIR Form 2307 - ${p.CompInvoiceId}</title>
  <style>body{font-family:Arial,sans-serif;font-size:12px;margin:24px;}table{width:100%;border-collapse:collapse;margin-top:12px;}th,td{border:1px solid #333;padding:6px;text-align:left;}th{background:#f1f5f9;}</style></head>
  <body><h2>BIR Form No. 2307 - Certificate of Creditable Tax Withheld at Source</h2>
  <p><strong>Period:</strong> ${periodFrom} to ${periodTo} | <strong>Invoice:</strong> ${p.CompInvoiceId} | <strong>EisUniqueId:</strong> ${p.EisUniqueId}</p>
  <p><strong>Payee:</strong> ${payee.RegNm} (TIN: ${payee.TIN}-${payee.BranchCd})</p>
  <p><strong>Payor (Withholding Agent):</strong> ${payor.RegNm} (TIN: ${payor.TIN ?? '000000000'}-${payor.BranchCd ?? '0000'})</p>
  <table><tr><th>ATC</th><th>Income Payment Description</th><th>Total Payment (PHP)</th><th>Rate</th><th>Tax Withheld (PHP)</th></tr>
  ${lines.map((l) => `<tr><td>${l.atcCode}</td><td>${l.description}</td><td>${l.totalIncomePayment.toFixed(2)}</td><td>${l.taxRatePct}%</td><td>${l.taxWithheld.toFixed(2)}</td></tr>`).join('')}
  </table><h3>Total Tax Withheld: PHP ${p.Summary.WithholdingTaxAmt.toFixed(2)}</h3></body></html>`;

  return {
    formTitle: 'BIR Form No. 2307 - Certificate of Creditable Tax Withheld at Source',
    periodFrom,
    periodTo,
    payee: {
      tin: payee.TIN,
      branchCd: payee.BranchCd,
      name: payee.RegNm,
      address: payeeAddr,
    },
    payor: {
      tin: payor.TIN ?? '000000000',
      branchCd: payor.BranchCd ?? '0000',
      name: payor.RegNm,
      address: payorAddr,
    },
    referenceInvoice: p.CompInvoiceId,
    eisUniqueId: p.EisUniqueId,
    lines,
    totalTaxWithheld: p.Summary.WithholdingTaxAmt,
    printableHtml,
  };
}

/**
 * RMC 5-2021 Annex B Immutable Hash-Chained Audit Trail Service.
 */
export class AuditTrailService {
  private entries: AuditTrailEntry[] = [];

  public loadEntries(existing: AuditTrailEntry[]): void {
    this.entries = [...existing];
  }

  public getEntries(): AuditTrailEntry[] {
    return [...this.entries];
  }

  public append(params: {
    actor: string;
    action: string;
    taxpayerTin: string;
    entityType: string;
    entityId: string;
    details: string;
  }): AuditTrailEntry {
    const seq = this.entries.length + 1;
    const prevHash =
      this.entries.length > 0
        ? this.entries[this.entries.length - 1].entryHash
        : 'GENESIS-BIR-ANNEX-B';
    const timestamp = new Date().toISOString();
    const id = `AUD-${String(seq).padStart(6, '0')}`;

    const canonical = JSON.stringify({
      seq,
      id,
      timestamp,
      actor: params.actor,
      action: params.action,
      taxpayerTin: params.taxpayerTin,
      entityType: params.entityType,
      entityId: params.entityId,
      details: params.details,
      prevHash,
    });
    const entryHash = crypto.createHash('sha256').update(canonical).digest('hex');

    const entry: AuditTrailEntry = {
      seq,
      id,
      timestamp,
      ...params,
      prevHash,
      entryHash,
    };
    this.entries.push(entry);
    return entry;
  }

  public verifyIntegrity(): { valid: boolean; totalEntries: number; brokenAtSeq: number | null } {
    let expectedPrev = 'GENESIS-BIR-ANNEX-B';
    for (const e of this.entries) {
      if (e.prevHash !== expectedPrev) {
        return { valid: false, totalEntries: this.entries.length, brokenAtSeq: e.seq };
      }
      const canonical = JSON.stringify({
        seq: e.seq,
        id: e.id,
        timestamp: e.timestamp,
        actor: e.actor,
        action: e.action,
        taxpayerTin: e.taxpayerTin,
        entityType: e.entityType,
        entityId: e.entityId,
        details: e.details,
        prevHash: e.prevHash,
      });
      const recomputed = crypto.createHash('sha256').update(canonical).digest('hex');
      if (recomputed !== e.entryHash) {
        return { valid: false, totalEntries: this.entries.length, brokenAtSeq: e.seq };
      }
      expectedPrev = e.entryHash;
    }
    return { valid: true, totalEntries: this.entries.length, brokenAtSeq: null };
  }
}
