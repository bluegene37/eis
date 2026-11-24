// Gene - Nov, 24, 2026: BIR Statutory Report Generators (RELIEF SLSP, SAWT, QAP 1601-EQ, Form 2307)
// with exact centavo totals and HTML-escaped printable certificates.
import {
  type BirAddress,
  type BirEisPayloadV201,
  fromCents,
  round2,
  toCents,
} from './bir_tax.ts';

export interface StatutoryTaxpayerInfo {
  tin: string;
  registered_name: string;
  business_name: string;
  head_office_address?: BirAddress | null;
}

export interface StatutoryInvoiceRow {
  direction: string;
  payload: BirEisPayloadV201;
}

function escapeHtml(text: string): string {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

export function generateSlspReport(
  taxpayer: StatutoryTaxpayerInfo,
  records: StatutoryInvoiceRow[],
  kind: 'SALES' | 'PURCHASES' | string,
  fiscalPeriod: string,
): Record<string, unknown> {
  const filtered = records.filter((r) =>
    kind === 'SALES' ? r.direction === 'SALES' : r.direction === 'PURCHASE',
  );
  const headOffice = taxpayer.head_office_address ?? null;

  const totalExempt = fromCents(
    filtered.reduce((s, r) => s + toCents(r.payload.Summary.VATExemptSales), 0),
  );
  const totalZero = fromCents(
    filtered.reduce((s, r) => s + toCents(r.payload.Summary.ZeroRatedSales), 0),
  );
  const totalVatable = fromCents(
    filtered.reduce((s, r) => s + toCents(r.payload.Summary.VATableSales), 0),
  );
  const totalVat = fromCents(
    filtered.reduce((s, r) => s + toCents(r.payload.Summary.VATAmt), 0),
  );

  const headerType = kind === 'SALES' ? 'H,S' : 'H,P';
  const detailType = kind === 'SALES' ? 'D,S' : 'D,P';

  const datLines: string[] = [
    [
      headerType,
      `"${taxpayer.tin}"`,
      `"${taxpayer.registered_name.replaceAll('"', '')}"`,
      '""',
      '""',
      '""',
      `"${taxpayer.business_name.replaceAll('"', '')}"`,
      `"${headOffice?.Street ?? ''} ${headOffice?.Barangay ?? ''}"`,
      `"${headOffice?.City ?? ''} ${headOffice?.Province ?? ''}"`,
      totalExempt.toFixed(2),
      totalZero.toFixed(2),
      totalVatable.toFixed(2),
      totalVat.toFixed(2),
      '"009"',
      fiscalPeriod,
      '12',
    ].join(','),
  ];

  const csvLines: string[] = [
    'TAXABLE_MONTH,TIN,REGISTERED_NAME,ADDRESS,EXEMPT_SALES,ZERO_RATED_SALES,TAXABLE_SALES,OUTPUT_INPUT_VAT,REFERENCE_INVOICE',
  ];

  for (const r of filtered) {
    const p = r.payload;
    const partyTin =
      (kind === 'SALES' ? p.Buyer.TIN : p.Seller.TIN) ?? '000000000';
    const partyName = kind === 'SALES' ? p.Buyer.RegNm : p.Seller.RegNm;
    const partyAddrObj = kind === 'SALES' ? p.Buyer.Address : p.Seller.Address;
    const addr = partyAddrObj
      ? `${partyAddrObj.Street} ${partyAddrObj.City}`.trim()
      : 'PHILIPPINES';

    datLines.push(
      [
        detailType,
        `"${partyTin}"`,
        `"${partyName.replaceAll('"', '')}"`,
        '""',
        '""',
        '""',
        `"${addr.replaceAll('"', '')}"`,
        '""',
        p.Summary.VATExemptSales.toFixed(2),
        p.Summary.ZeroRatedSales.toFixed(2),
        p.Summary.VATableSales.toFixed(2),
        p.Summary.VATAmt.toFixed(2),
        `"${taxpayer.tin}"`,
        `${p.IssueDtm.slice(0, 7).replace(/-/g, '')}01`,
      ].join(','),
    );

    csvLines.push(
      [
        p.IssueDtm.slice(0, 7),
        partyTin,
        `"${partyName.replaceAll('"', '')}"`,
        `"${addr.replaceAll('"', '')}"`,
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

export function generateWithholdingDatReport(
  taxpayer: StatutoryTaxpayerInfo,
  records: StatutoryInvoiceRow[],
  reportKind: 'SAWT' | 'QAP' | string,
  periodQuarter: string,
): Record<string, unknown> {
  const applicable = records.filter((r) => {
    if (r.payload.Summary.WithholdingTaxAmt <= 0) return false;
    return reportKind === 'SAWT'
      ? r.direction === 'SALES'
      : r.direction === 'PURCHASE';
  });

  const formCode = reportKind === 'SAWT' ? '1702Q' : '1601EQ';
  const headerCode = reportKind === 'SAWT' ? 'HSAWT' : 'HQAP';
  const detailCode = reportKind === 'SAWT' ? 'DSAWT' : 'DQAP';

  const totalBase = fromCents(
    applicable.reduce((s, r) => s + toCents(r.payload.Summary.NetSales), 0),
  );
  const totalTaxWithheld = fromCents(
    applicable.reduce(
      (s, r) => s + toCents(r.payload.Summary.WithholdingTaxAmt),
      0,
    ),
  );

  const datLines: string[] = [
    [
      headerCode,
      `H${formCode}`,
      taxpayer.tin,
      '0000',
      `"${taxpayer.registered_name.replaceAll('"', '')}"`,
      periodQuarter,
      '009',
    ].join(','),
  ];

  const csvLines: string[] = [
    'SEQ,COUNTERPARTY_TIN,BRANCH_CD,REGISTERED_NAME,ATC_CODE,TAX_BASE,TAX_RATE_PCT,TAX_WITHHELD,INVOICE_NO',
  ];

  applicable.forEach((rec, idx) => {
    const p = rec.payload;
    const partyTin =
      (reportKind === 'SAWT' ? p.Buyer.TIN : p.Seller.TIN) ?? '000000000';
    const partyBranch =
      (reportKind === 'SAWT' ? p.Buyer.BranchCd : p.Seller.BranchCd) ?? '0000';
    const partyName = reportKind === 'SAWT' ? p.Buyer.RegNm : p.Seller.RegNm;

    const atcItem = p.ItemList.find((i) => i.AtcCode != null);
    const atc = atcItem?.AtcCode ?? 'WC160';
    const ratePct = round2((atcItem?.CwtRate ?? 0.02) * 100);

    datLines.push(
      [
        detailCode,
        `D${formCode}`,
        idx + 1,
        partyTin,
        partyBranch,
        `"${partyName.replaceAll('"', '')}"`,
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
        partyTin,
        partyBranch,
        `"${partyName.replaceAll('"', '')}"`,
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

export function generateBirForm2307(
  p: BirEisPayloadV201,
): Record<string, unknown> {
  const issueDate = new Date(p.IssueDtm);
  const year = issueDate.getFullYear();
  const quarterIndex = Math.floor(issueDate.getMonth() / 3);
  const startMonth = quarterIndex * 3 + 1;
  const monthInQuarter = (issueDate.getMonth() % 3) + 1;

  const periodFrom = `${year}-${startMonth.toString().padStart(2, '0')}-01`;
  const endMonth = startMonth + 2;
  const lastDay = endMonth === 6 || endMonth === 9 ? '30' : '31';
  const periodTo = `${year}-${endMonth.toString().padStart(2, '0')}-${lastDay}`;

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

  const payeeAddr = `${p.Seller.Address.Street}, ${p.Seller.Address.City}, ${p.Seller.Address.Province}`;
  const payorAddr = p.Buyer.Address
    ? `${p.Buyer.Address.Street}, ${p.Buyer.Address.City}, ${p.Buyer.Address.Province}`
    : 'Metro Manila, Philippines';

  const rowsHtml = lines
    .map(
      (l) =>
        `<tr><td>${escapeHtml(String(l.atcCode))}</td><td>${escapeHtml(String(l.description))}</td>` +
        `<td>${Number(l.totalIncomePayment).toFixed(2)}</td>` +
        `<td>${l.taxRatePct}%</td>` +
        `<td>${Number(l.taxWithheld).toFixed(2)}</td></tr>`,
    )
    .join('');

  const printableHtml =
    `<!DOCTYPE html><html><head><meta charset="utf-8"><title>BIR Form 2307 - ${escapeHtml(p.CompInvoiceId)}</title>` +
    '<style>body{font-family:Arial,sans-serif;font-size:12px;margin:24px;}table{width:100%;border-collapse:collapse;margin-top:12px;}th,td{border:1px solid #333;padding:6px;text-align:left;}th{background:#f1f5f9;}</style></head>' +
    '<body><h2>BIR Form No. 2307 - Certificate of Creditable Tax Withheld at Source</h2>' +
    `<p><strong>Period:</strong> ${escapeHtml(periodFrom)} to ${escapeHtml(periodTo)} | <strong>Invoice:</strong> ${escapeHtml(p.CompInvoiceId)} | <strong>EisUniqueId:</strong> ${escapeHtml(p.EisUniqueId)}</p>` +
    `<p><strong>Payee:</strong> ${escapeHtml(p.Seller.RegNm)} (TIN: ${escapeHtml(p.Seller.TIN)}-${escapeHtml(p.Seller.BranchCd)})</p>` +
    `<p><strong>Payor (Withholding Agent):</strong> ${escapeHtml(p.Buyer.RegNm)} (TIN: ${escapeHtml(p.Buyer.TIN ?? '000000000')}-${escapeHtml(p.Buyer.BranchCd ?? '0000')})</p>` +
    '<table><tr><th>ATC</th><th>Income Payment Description</th><th>Total Payment (PHP)</th><th>Rate</th><th>Tax Withheld (PHP)</th></tr>' +
    rowsHtml +
    `</table><h3>Total Tax Withheld: PHP ${p.Summary.WithholdingTaxAmt.toFixed(2)}</h3></body></html>`;

  return {
    formTitle:
      'BIR Form No. 2307 - Certificate of Creditable Tax Withheld at Source',
    periodFrom,
    periodTo,
    payee: {
      tin: p.Seller.TIN,
      branchCd: p.Seller.BranchCd,
      name: p.Seller.RegNm,
      address: payeeAddr,
    },
    payor: {
      tin: p.Buyer.TIN ?? '000000000',
      branchCd: p.Buyer.BranchCd ?? '0000',
      name: p.Buyer.RegNm,
      address: payorAddr,
    },
    referenceInvoice: p.CompInvoiceId,
    eisUniqueId: p.EisUniqueId,
    lines,
    totalTaxWithheld: p.Summary.WithholdingTaxAmt,
    printableHtml,
  };
}
