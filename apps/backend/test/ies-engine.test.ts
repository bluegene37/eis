import { describe, expect, it } from 'vitest';
import {
  buildEisUniqueId,
  normalizeTin9,
  validateBirSchemaV201,
} from '../src/domain/bir-eis-schema.js';
import {
  decryptAes256Envelope,
  encryptJwsWithAes256,
  generateTaxpayerCryptoBundle,
  signBirPayloadJws,
  verifyBirPayloadJws,
} from '../src/services/crypto-jws-aes.service.js';
import { IesEngineService } from '../src/services/ies-engine.service.js';
import { computeBirTaxBreakdown } from '../src/services/tax-calculator.service.js';

function createTestEngine(): IesEngineService {
  const engine = new IesEngineService({ persistPath: null });
  engine.registerTaxpayer({
    tin: '009123456',
    taxType: 'VAT',
    registeredName: 'Test Manila Corp.',
    businessName: 'Test Manila',
    email: 'tax@testmanila.ph',
    eisCertId: 'EISC2026',
    headOfficeAddress: {
      Street: '123 Ayala Ave',
      Barangay: 'Bel-Air',
      City: 'Makati City',
      Province: 'Metro Manila',
      ZipCode: '1226',
    },
  });
  return engine;
}

describe('Philippine BIR EIS & CAS Compliance Engine', () => {
  it('generates valid 24-character EisUniqueId and gapless sequence across invoices', async () => {
    const id1 = buildEisUniqueId(new Date('2026-11-17T10:00:00'), 'EISC2026', 1);
    const id2 = buildEisUniqueId(new Date('2026-11-17T10:05:00'), 'EISC2026', 2);

    expect(id1).toBe('20261117EISC202600000001');
    expect(id1.length).toBe(24);
    expect(id2).toBe('20261117EISC202600000002');
    expect(normalizeTin9('009-123-456-0000')).toBe('009123456');
  });

  it('computes EOPT RR 7-2024 VATable, Senior Citizen VAT-Exempt + 20% Discount, Zero-Rated, and CWT ATC math', () => {
    // 1. Standard 12% VATable + WC160 (2% CWT)
    const b2b = computeBirTaxBreakdown(
      [{ itemNm: 'IT Consultancy', qty: 1, unitPrice: 100000, taxClassification: 'VATABLE', atcCode: 'WC160' }],
      'VAT',
      'REGULAR',
    );
    expect(b2b.summary.VATableSales).toBe(100000);
    expect(b2b.summary.VATAmt).toBe(12000);
    expect(b2b.summary.WithholdingTaxAmt).toBe(2000);
    expect(b2b.summary.TotalAmountDue).toBe(110000); // 100k + 12k VAT - 2k CWT

    // 2. Senior Citizen (VAT-inclusive 1,120 -> VAT-exempt 1,000 -> less 20% = 800)
    const sc = computeBirTaxBreakdown(
      [{ itemNm: 'Essential Medical Device', qty: 1, unitPrice: 1120, priceIncludesVat: true }],
      'VAT',
      'SENIOR_CITIZEN',
    );
    expect(sc.summary.GrossSalesAmt).toBe(1000);
    expect(sc.summary.ScPwdDiscountAmt).toBe(200);
    expect(sc.summary.VATExemptSales).toBe(800);
    expect(sc.summary.VATAmt).toBe(0);
    expect(sc.summary.TotalAmountDue).toBe(800);

    // 3. Zero-Rated Export
    const zr = computeBirTaxBreakdown(
      [{ itemNm: 'Export Software', qty: 2, unitPrice: 25000, taxClassification: 'ZERO_RATED' }],
      'VAT',
      'REGULAR',
    );
    expect(zr.summary.ZeroRatedSales).toBe(50000);
    expect(zr.summary.VATAmt).toBe(0);
    expect(zr.summary.TotalAmountDue).toBe(50000);
  });

  it('signs JWS (RS256), detects tampering, and completes AES-256-GCM encryption roundtrip', async () => {
    const bundle = generateTaxpayerCryptoBundle('009123456', 'EISC2026');
    const sample = { EisUniqueId: '20261117EISC202600000001', NetSales: 1000 };

    const jws = await signBirPayloadJws(sample, bundle.privateKeyPem, bundle.keyId);
    const envelope = encryptJwsWithAes256(jws, bundle.aesKeyHex);
    const decryptedJws = decryptAes256Envelope(envelope, bundle.aesKeyHex);

    expect(decryptedJws).toBe(jws);

    const verified = await verifyBirPayloadJws<typeof sample>(decryptedJws, bundle.publicKeyPem);
    expect(verified.valid).toBe(true);
    expect(verified.payload?.NetSales).toBe(1000);

    // Tamper payload portion of JWS
    const parts = decryptedJws.split('.');
    parts[1] = Buffer.from(JSON.stringify({ EisUniqueId: '20261117EISC202600000001', NetSales: 999999 })).toString('base64url');
    const tampered = await verifyBirPayloadJws(parts.join('.'), bundle.publicKeyPem);
    expect(tampered.valid).toBe(false);
  });

  it('simulates BIR EIS ACK-200, SYN004, VAL001, DUP001, and 3-day retry queue outage recovery', async () => {
    const engine = createTestEngine();

    // 1. Valid transmission -> ACK-200
    const ok = await engine.ingestAndTransmitInvoice({
      sourceSystem: 'IES_UI',
      transClass: 'B2B',
      buyerName: 'Ayala Buyer Corp',
      buyerTin: '008111222',
      items: [{ itemNm: 'Cloud Platform', qty: 1, unitPrice: 10000 }],
    });
    expect(ok.status).toBe('TRANSMITTED');
    expect(ok.lastReceipt?.ackCode).toBe('ACK-200');
    expect(ok.payload.EisUniqueId.length).toBe(24);

    // 2. Missing B2B Buyer TIN -> SYN004 rejection
    const synErr = await engine.ingestAndTransmitInvoice(
      {
        sourceSystem: 'IES_UI',
        transClass: 'B2B',
        buyerName: 'Missing TIN Corp',
        buyerTin: '008111222',
        items: [{ itemNm: 'Consulting', qty: 1, unitPrice: 5000 }],
      },
      { forceInvalidPayload: true },
    );
    expect(synErr.status).toBe('REJECTED');
    expect(synErr.lastReceipt?.ackCode).toBe('SYN004');

    // 3. Direct Simulator VAL001 & DUP001 checks
    const tp = engine.getTaxpayerById();
    const tamperedMathPayload = structuredClone(ok.payload);
    tamperedMathPayload.EisUniqueId = '20261117EISC202600000099';
    tamperedMathPayload.Summary.VATAmt = 99999; // invalid math
    const badJws = await signBirPayloadJws(tamperedMathPayload, tp.privateKeyPem, tp.keyId);
    const badEnv = encryptJwsWithAes256(badJws, tp.aesKeyHex);
    const valResp = await engine.gateway.transmitEnvelope(badEnv, tp);
    expect(valResp.ackCode).toBe('VAL001');

    // Duplicate EisUniqueId -> DUP001
    const dupResp = await engine.gateway.transmitEnvelope(ok.aesEnvelope, tp);
    expect(dupResp.ackCode).toBe('DUP001');

    // 4. Outage mode -> QUEUED_RETRY -> Recovery via processRetryQueue()
    engine.setGatewayConfig({ simulateOutage: true });
    const queued = await engine.ingestAndTransmitInvoice({
      sourceSystem: 'IES_UI',
      transClass: 'B2C',
      buyerName: 'Walk-in Customer',
      items: [{ itemNm: 'POS Retail Item', qty: 2, unitPrice: 500 }],
    });
    expect(queued.status).toBe('QUEUED_RETRY');
    expect(queued.lastReceipt?.ackCode).toBe('NET503');

    engine.setGatewayConfig({ simulateOutage: false });
    const retryResult = await engine.processRetryQueue();
    expect(retryResult.processed).toBe(1);
    expect(retryResult.succeeded).toBe(1);
    const updated = engine.getInvoices().find((i) => i.id === queued.id);
    expect(updated?.status).toBe('TRANSMITTED');
    expect(updated?.lastReceipt?.ackCode).toBe('ACK-200');
  });

  it('ingests Xero, QuickBooks Online, Odoo, and CSV batch into BIR v2.01, balanced CAS books, .DAT exports, and verified Annex B audit trail', async () => {
    const engine = createTestEngine();

    const xeroInv = await engine.ingestFromXero({
      InvoiceID: 'xero-1',
      InvoiceNumber: 'X-001',
      Type: 'ACCREC',
      Contact: { Name: 'Xero PH Client', TaxNumber: '007111222' },
      LineItems: [{ Description: 'SaaS Subscription', Quantity: 1, UnitAmount: 10000, TaxType: 'OUTPUT', AtcCode: 'WC160' }],
    });
    expect(xeroInv.status).toBe('TRANSMITTED');
    expect(validateBirSchemaV201(xeroInv.payload)).toEqual([]);

    const qboBill = await engine.ingestFromQuickBooks({
      Id: 'qbo-1',
      DocNumber: 'Q-BILL-1',
      TxnType: 'Bill',
      CustomerRef: { name: 'QBO PH Vendor', tin: '006222333' },
      Line: [{ Description: 'Cloud Hosting', SalesItemLineDetail: { Qty: 1, UnitPrice: 5000, TaxCodeRef: { value: 'VAT12' }, AtcCode: 'WC160' } }],
    });
    expect(qboBill.direction).toBe('PURCHASE');
    expect(qboBill.status).toBe('TRANSMITTED');

    const odooInv = await engine.ingestFromOdoo({
      id: 42,
      name: 'ODOO/2026/01',
      move_type: 'out_invoice',
      partner_id: { name: 'Odoo Buyer Inc', vat: '005444555' },
      invoice_line_ids: [{ name: 'ERP Implementation', quantity: 1, price_unit: 20000, tax_ids: ['VAT_12'] }],
    });
    expect(odooInv.status).toBe('TRANSMITTED');

    const csvBatch = await engine.ingestFromCsvBatch(
      [
        'CompInvoiceId,BuyerName,BuyerTin,DocType,TransClass,ItemNm,Qty,UnitPrice,TaxClassification,AtcCode',
        'CSV-001,Batch Client One,004111222,01,B2B,Printer Ink,3,1000,VATABLE,',
      ].join('\n'),
    );
    expect(csvBatch.length).toBe(1);
    expect(csvBatch[0].status).toBe('TRANSMITTED');

    // Issue Credit Memo (DocType 03, CorrYN Y)
    const cm = await engine.issueCreditMemo(odooInv.id, 'Service adjustment');
    expect(cm.payload.DocType).toBe('03');
    expect(cm.payload.CorrYN).toBe('Y');
    expect(cm.payload.RefEisUniqueId).toBe(odooInv.payload.EisUniqueId);

    // CAS Books Trial Balance invariant (Total Debits === Total Credits)
    const books = engine.getCasBooks();
    expect(books.trialBalance.isBalanced).toBe(true);
    expect(books.trialBalance.totalDebits).toBeGreaterThan(0);
    expect(books.trialBalance.totalDebits).toBe(books.trialBalance.totalCredits);

    // Verify Sales Journal, Purchase Journal, General Journal all populated
    expect(books.entries.some((e) => e.bookType === 'SJ')).toBe(true);
    expect(books.entries.some((e) => e.bookType === 'PJ')).toBe(true);
    expect(books.entries.some((e) => e.bookType === 'GJ')).toBe(true);

    // Statutory Reports: SLSP Sales, SAWT, QAP, Form 2307
    const slspSales = engine.generateSlsp(undefined, 'SALES', '202611');
    expect(slspSales.datContent).toContain('H,S,');
    expect(slspSales.datContent).toContain('D,S,');

    const sawt = engine.generateWithholdingDat(undefined, 'SAWT', '202612');
    expect(sawt.datContent).toContain('HSAWT,H1702Q');
    expect(sawt.rowCount).toBe(1);

    const qap = engine.generateWithholdingDat(undefined, 'QAP', '202612');
    expect(qap.datContent).toContain('HQAP,H1601EQ');
    expect(qap.rowCount).toBe(1);

    const f2307 = engine.generateForm2307ForInvoice(xeroInv.id);
    expect(f2307.totalTaxWithheld).toBe(200);
    expect(f2307.printableHtml).toContain('BIR Form No. 2307');

    // RMC 5-2021 Annex B Audit Trail hash chain integrity
    const audit = engine.auditTrail.verifyIntegrity();
    expect(audit.valid).toBe(true);
    expect(audit.totalEntries).toBeGreaterThanOrEqual(8);
  });
});
