import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {
  BirAddress,
  BirEisPayloadV201,
  BirGatewayMode,
  BirGatewayReceipt,
  StoredInvoiceRecord,
  TaxType,
  TaxpayerBranch,
  TaxpayerProfile,
  buildEisUniqueId,
  formatBirDateTime,
  normalizeBranchCd,
  normalizeTin9,
} from '../domain/bir-eis-schema.js';
import {
  CanonicalIngestInput,
  OdooAccountMovePayload,
  QuickBooksInvoicePayload,
  XeroInvoicePayload,
  mapOdooToCanonical,
  mapQuickBooksToCanonical,
  mapXeroToCanonical,
  parseCsvBatchToCanonical,
} from '../connectors/erp-connectors.service.js';
import { BirSimulatorGatewayService } from './bir-simulator-gateway.service.js';
import {
  BirBookType,
  CasJournalEntry,
  PFRS_CHART_OF_ACCOUNTS,
  computeTrialBalance,
  createJournalEntriesForInvoice,
} from './cas-books.service.js';
import {
  encryptJwsWithAes256,
  generateTaxpayerCryptoBundle,
  signBirPayloadJws,
} from './crypto-jws-aes.service.js';
import {
  AuditTrailEntry,
  AuditTrailService,
  BirForm2307Payload,
  generateBirForm2307,
  generateSlspReport,
  generateWithholdingDatReport,
} from './statutory-reports.service.js';
import { BIR_ATC_CATALOG, computeBirTaxBreakdown, round2 } from './tax-calculator.service.js';

interface PersistedState {
  taxpayers: TaxpayerProfile[];
  invoices: StoredInvoiceRecord[];
  journalEntries: CasJournalEntry[];
  auditEntries: AuditTrailEntry[];
}

export class IesEngineService {
  private taxpayers: TaxpayerProfile[] = [];
  private invoices: StoredInvoiceRecord[] = [];
  private journalEntries: CasJournalEntry[] = [];
  public readonly gateway = new BirSimulatorGatewayService();
  public readonly auditTrail = new AuditTrailService();
  private readonly persistPath: string | null;

  constructor(options?: { persistPath?: string | null }) {
    this.persistPath = options?.persistPath === undefined ? null : options.persistPath;
    if (this.persistPath && fs.existsSync(this.persistPath)) {
      this.loadFromDisk();
    }
  }

  private saveToDisk(): void {
    if (!this.persistPath) return;
    const dir = path.dirname(this.persistPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    const snapshot: PersistedState = {
      taxpayers: this.taxpayers,
      invoices: this.invoices,
      journalEntries: this.journalEntries,
      auditEntries: this.auditTrail.getEntries(),
    };
    fs.writeFileSync(this.persistPath, JSON.stringify(snapshot, null, 2), 'utf8');
  }

  private loadFromDisk(): void {
    if (!this.persistPath || !fs.existsSync(this.persistPath)) return;
    const raw = fs.readFileSync(this.persistPath, 'utf8');
    const data = JSON.parse(raw) as PersistedState;
    this.taxpayers = data.taxpayers ?? [];
    this.invoices = data.invoices ?? [];
    this.journalEntries = data.journalEntries ?? [];
    this.auditTrail.loadEntries(data.auditEntries ?? []);
    for (const inv of this.invoices) {
      if (inv.status === 'TRANSMITTED') {
        this.gateway.registerKnownEisId(inv.payload.EisUniqueId);
      }
    }
  }

  public getTaxpayers(): TaxpayerProfile[] {
    return this.taxpayers;
  }

  public getTaxpayerById(id?: string): TaxpayerProfile {
    if (id) {
      const found = this.taxpayers.find((t) => t.id === id);
      if (found) return found;
    }
    if (this.taxpayers.length === 0) {
      throw new Error('No Taxpayer TIN registered yet.');
    }
    return this.taxpayers[0];
  }

  public registerTaxpayer(input: {
    workspaceId?: string;
    tin: string;
    taxType: TaxType;
    registeredName: string;
    businessName: string;
    email: string;
    eisCertId?: string;
    pttNumber?: string;
    headOfficeAddress: BirAddress;
  }): TaxpayerProfile {
    const tin = normalizeTin9(input.tin);
    const eisCertId = (input.eisCertId || `EC${tin.slice(0, 6)}`).toUpperCase().slice(0, 8);
    const cryptoBundle = generateTaxpayerCryptoBundle(tin, eisCertId);

    const profile: TaxpayerProfile = {
      id: `TP-${crypto.randomUUID().slice(0, 8).toUpperCase()}`,
      workspaceId: input.workspaceId ?? 'WS-PH-DEFAULT',
      tin,
      taxType: input.taxType,
      registeredName: input.registeredName.trim(),
      businessName: input.businessName.trim(),
      email: input.email.trim(),
      eisCertId,
      pttNumber: input.pttNumber ?? `PTT-2026-${tin.slice(-4)}`,
      publicKeyPem: cryptoBundle.publicKeyPem,
      privateKeyPem: cryptoBundle.privateKeyPem,
      aesKeyHex: cryptoBundle.aesKeyHex,
      keyId: cryptoBundle.keyId,
      branches: [
        {
          branchCd: '0000',
          branchName: 'Head Office',
          address: input.headOfficeAddress,
          lastSequence: 0,
          invoicePrefix: 'SI-0000',
        },
      ],
      createdAt: new Date().toISOString(),
    };

    this.taxpayers.push(profile);
    this.auditTrail.append({
      actor: 'system.admin',
      action: 'REGISTER_TAXPAYER_TIN',
      taxpayerTin: profile.tin,
      entityType: 'TaxpayerProfile',
      entityId: profile.id,
      details: `Registered ${profile.registeredName} (TIN ${profile.tin}, Cert ${profile.eisCertId}, RSA-2048 + AES-256 keys provisioned).`,
    });
    this.saveToDisk();
    return profile;
  }

  public addBranch(
    taxpayerId: string,
    input: { branchCd: string; branchName: string; address: BirAddress; invoicePrefix?: string },
  ): TaxpayerBranch {
    const tp = this.getTaxpayerById(taxpayerId);
    const branchCd = normalizeBranchCd(input.branchCd);
    if (tp.branches.some((b) => b.branchCd === branchCd)) {
      throw new Error(`BranchCd ${branchCd} already exists for TIN ${tp.tin}.`);
    }
    const branch: TaxpayerBranch = {
      branchCd,
      branchName: input.branchName.trim(),
      address: input.address,
      lastSequence: 0,
      invoicePrefix: input.invoicePrefix ?? `SI-${branchCd}`,
    };
    tp.branches.push(branch);
    this.auditTrail.append({
      actor: 'system.admin',
      action: 'ADD_BRANCH',
      taxpayerTin: tp.tin,
      entityType: 'TaxpayerBranch',
      entityId: branchCd,
      details: `Added Branch ${branchCd} (${branch.branchName}) under TIN ${tp.tin}.`,
    });
    this.saveToDisk();
    return branch;
  }

  public rotateTaxpayerKeys(taxpayerId: string): TaxpayerProfile {
    const tp = this.getTaxpayerById(taxpayerId);
    const bundle = generateTaxpayerCryptoBundle(tp.tin, tp.eisCertId);
    tp.keyId = bundle.keyId;
    tp.publicKeyPem = bundle.publicKeyPem;
    tp.privateKeyPem = bundle.privateKeyPem;
    tp.aesKeyHex = bundle.aesKeyHex;
    this.auditTrail.append({
      actor: 'security.officer',
      action: 'ROTATE_JWS_AES_KEYS',
      taxpayerTin: tp.tin,
      entityType: 'TaxpayerProfile',
      entityId: tp.id,
      details: `Rotated RSA-2048 JWS keypair (${tp.keyId}) and AES-256 key.`,
    });
    this.saveToDisk();
    return tp;
  }

  /**
   * Core pipeline:
   *  1. Allocate gapless sequential EisUniqueId & CompInvoiceId
   *  2. Compute EOPT (RR 7-2024) + CWT (RR 6-2026) taxes
   *  3. Build BIR EIS v2.01 payload
   *  4. Sign with RFC 7515 JWS (RS256) & encrypt with AES-256-GCM
   *  5. Transmit to configured BIR EIS Gateway (or queue on NET503 for 3-day retry)
   *  6. Post double-entry records into 6 Mandatory BIR CAS Books (RR 9-2009)
   *  7. Record RMC 5-2021 Annex B immutable audit log
   */
  public async ingestAndTransmitInvoice(
    input: CanonicalIngestInput,
    options?: { forceInvalidPayload?: boolean },
  ): Promise<StoredInvoiceRecord> {
    const tp = this.getTaxpayerById(input.taxpayerId);
    const branchCd = normalizeBranchCd(input.branchCd);
    const branch = tp.branches.find((b) => b.branchCd === branchCd) ?? tp.branches[0];

    const issueDate = input.issueDtm ? new Date(input.issueDtm) : new Date();
    const safeIssueDate = Number.isNaN(issueDate.getTime()) ? new Date() : issueDate;

    // Atomic sequential allocation
    branch.lastSequence += 1;
    const seqNum = branch.lastSequence;
    const eisUniqueId = buildEisUniqueId(safeIssueDate, tp.eisCertId, seqNum);
    const compInvoiceId =
      input.compInvoiceId?.trim() ||
      `${branch.invoicePrefix}-${String(seqNum).padStart(6, '0')}`;

    const buyerCategory = input.buyerCategory ?? 'REGULAR';
    const { itemList, summary } = computeBirTaxBreakdown(
      input.items,
      tp.taxType,
      buyerCategory,
      input.otherChargesAmt ?? 0,
    );

    const normalizedBuyerTin = input.buyerTin ? normalizeTin9(input.buyerTin) : null;
    const payload: BirEisPayloadV201 = {
      SchemaVer: 'v2.01',
      SystemType: input.systemType ?? 'CAS',
      EisUniqueId: eisUniqueId,
      CompInvoiceId: compInvoiceId,
      IssueDtm: formatBirDateTime(safeIssueDate),
      DocType: input.docType ?? '01',
      TransClass: input.transClass ?? (normalizedBuyerTin ? 'B2B' : 'B2C'),
      CorrYN: input.corrYN ?? (input.docType === '03' || input.docType === '04' ? 'Y' : 'N'),
      RefEisUniqueId: input.refEisUniqueId ?? null,
      Currency: 'PHP',
      Seller: {
        TIN: tp.tin,
        BranchCd: branch.branchCd,
        Type: tp.taxType,
        RegNm: tp.registeredName,
        BusinessNm: tp.businessName,
        Address: branch.address,
        Email: tp.email,
      },
      Buyer: {
        TIN: options?.forceInvalidPayload ? null : normalizedBuyerTin,
        BranchCd: normalizedBuyerTin ? normalizeBranchCd(input.buyerBranchCd) : null,
        RegNm: input.buyerName.trim(),
        Address: input.buyerAddress ?? null,
        BuyerCategory: buyerCategory,
        OsacaPwdId: input.osacaPwdId ?? null,
      },
      ItemList: itemList,
      Summary: summary,
    };

    const jwsToken = await signBirPayloadJws(payload, tp.privateKeyPem, tp.keyId);
    const aesEnvelope = encryptJwsWithAes256(jwsToken, tp.aesKeyHex);

    const receipt: BirGatewayReceipt = await this.gateway.transmitEnvelope(aesEnvelope, tp);
    const threeDayDeadline = new Date(safeIssueDate.getTime() + 3 * 24 * 60 * 60 * 1000);

    const status =
      receipt.accepted
        ? 'TRANSMITTED'
        : receipt.ackCode === 'NET503'
          ? 'QUEUED_RETRY'
          : 'REJECTED';

    const record: StoredInvoiceRecord = {
      id: `INV-${crypto.randomUUID().slice(0, 8).toUpperCase()}`,
      taxpayerId: tp.id,
      branchCd: branch.branchCd,
      sourceSystem: input.sourceSystem,
      externalRefId: input.externalRefId ?? null,
      direction: input.direction ?? 'SALES',
      isPaid: input.isPaid ?? false,
      payload,
      jwsToken,
      aesEnvelope,
      status,
      retryCount: status === 'QUEUED_RETRY' ? 1 : 0,
      nextRetryAt:
        status === 'QUEUED_RETRY'
          ? new Date(Date.now() + 5 * 60 * 1000).toISOString()
          : null,
      threeDayDeadlineAt: threeDayDeadline.toISOString(),
      lastReceipt: receipt,
      createdAt: new Date().toISOString(),
    };

    this.invoices.unshift(record);

    // Post to 6 Mandatory BIR Books when accepted or queued within 3-day window (not rejected by syntax/math)
    if (status !== 'REJECTED') {
      const newEntries = createJournalEntriesForInvoice(record);
      this.journalEntries.unshift(...newEntries);
    }

    this.auditTrail.append({
      actor: `connector.${input.sourceSystem.toLowerCase()}`,
      action: `EIS_INGEST_${status}`,
      taxpayerTin: tp.tin,
      entityType: 'Invoice',
      entityId: payload.EisUniqueId,
      details: `${compInvoiceId} | ${receipt.ackCode} | NetSales PHP ${summary.NetSales.toFixed(2)} | VAT PHP ${summary.VATAmt.toFixed(2)} | CWT PHP ${summary.WithholdingTaxAmt.toFixed(2)}`,
    });

    this.saveToDisk();
    return record;
  }

  /**
   * Processes all QUEUED_RETRY invoices (3-day BIR SLA retry worker).
   */
  public async processRetryQueue(): Promise<{
    processed: number;
    succeeded: number;
    stillQueued: number;
  }> {
    const queued = this.invoices.filter((i) => i.status === 'QUEUED_RETRY');
    let succeeded = 0;
    let stillQueued = 0;

    for (const inv of queued) {
      const tp = this.getTaxpayerById(inv.taxpayerId);
      const receipt = await this.gateway.transmitEnvelope(inv.aesEnvelope, tp);
      inv.lastReceipt = receipt;
      inv.retryCount += 1;

      if (receipt.accepted) {
        inv.status = 'TRANSMITTED';
        inv.nextRetryAt = null;
        succeeded += 1;
        this.auditTrail.append({
          actor: 'worker.retry_queue',
          action: 'EIS_RETRY_TRANSMITTED',
          taxpayerTin: tp.tin,
          entityType: 'Invoice',
          entityId: inv.payload.EisUniqueId,
          details: `Recovered via 3-day SLA queue on attempt #${inv.retryCount}: ${receipt.birAckId}`,
        });
      } else if (receipt.ackCode === 'NET503') {
        inv.nextRetryAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
        stillQueued += 1;
      } else {
        inv.status = 'REJECTED';
        inv.nextRetryAt = null;
      }
    }

    this.saveToDisk();
    return { processed: queued.length, succeeded, stillQueued };
  }

  /**
   * Issues a BIR EOPT Credit Memo (DocType "03", CorrYN "Y") referencing an existing invoice.
   */
  public async issueCreditMemo(invoiceId: string, reason = 'Sales Return / Price Adjustment'): Promise<StoredInvoiceRecord> {
    const orig = this.invoices.find((i) => i.id === invoiceId);
    if (!orig) {
      throw new Error(`Invoice ${invoiceId} not found.`);
    }
    const p = orig.payload;
    return this.ingestAndTransmitInvoice({
      taxpayerId: orig.taxpayerId,
      branchCd: orig.branchCd,
      sourceSystem: 'IES_UI',
      systemType: p.SystemType,
      docType: '03',
      transClass: p.TransClass,
      direction: orig.direction,
      isPaid: orig.isPaid,
      corrYN: 'Y',
      refEisUniqueId: p.EisUniqueId,
      buyerName: p.Buyer.RegNm,
      buyerTin: p.Buyer.TIN,
      buyerBranchCd: p.Buyer.BranchCd,
      buyerCategory: p.Buyer.BuyerCategory,
      buyerAddress: p.Buyer.Address,
      items: p.ItemList.map((i) => ({
        itemCd: i.ItemCd,
        itemNm: `${i.ItemNm} (${reason})`,
        unit: i.Unit,
        qty: i.Qty,
        unitPrice: i.UnitCost,
        taxClassification: i.TaxClassification,
        regularDiscountAmt: i.DiscountAmt,
        atcCode: i.AtcCode,
      })),
    });
  }

  public async ingestFromXero(payload: XeroInvoicePayload, taxpayerId?: string): Promise<StoredInvoiceRecord> {
    return this.ingestAndTransmitInvoice(mapXeroToCanonical(payload, taxpayerId));
  }

  public async ingestFromQuickBooks(payload: QuickBooksInvoicePayload, taxpayerId?: string): Promise<StoredInvoiceRecord> {
    return this.ingestAndTransmitInvoice(mapQuickBooksToCanonical(payload, taxpayerId));
  }

  public async ingestFromOdoo(payload: OdooAccountMovePayload, taxpayerId?: string): Promise<StoredInvoiceRecord> {
    return this.ingestAndTransmitInvoice(mapOdooToCanonical(payload, taxpayerId));
  }

  public async ingestFromCsvBatch(csvText: string, taxpayerId?: string): Promise<StoredInvoiceRecord[]> {
    const items = parseCsvBatchToCanonical(csvText, taxpayerId);
    const results: StoredInvoiceRecord[] = [];
    for (const item of items) {
      results.push(await this.ingestAndTransmitInvoice(item));
    }
    return results;
  }

  public getInvoices(taxpayerId?: string): StoredInvoiceRecord[] {
    if (!taxpayerId) return this.invoices;
    return this.invoices.filter((i) => i.taxpayerId === taxpayerId);
  }

  public getCasBooks(params?: { taxpayerId?: string; bookType?: BirBookType | 'ALL' }) {
    let entries = this.journalEntries;
    if (params?.taxpayerId) {
      entries = entries.filter((e) => e.taxpayerId === params.taxpayerId);
    }
    if (params?.bookType && params.bookType !== 'ALL' && params.bookType !== 'GL') {
      entries = entries.filter((e) => e.bookType === params.bookType);
    }
    const trialBalance = computeTrialBalance(
      params?.taxpayerId
        ? this.journalEntries.filter((e) => e.taxpayerId === params.taxpayerId)
        : this.journalEntries,
    );
    return {
      chartOfAccounts: PFRS_CHART_OF_ACCOUNTS,
      entries,
      trialBalance,
    };
  }

  public getDashboardSummary(taxpayerId?: string) {
    const invs = this.getInvoices(taxpayerId);
    const transmitted = invs.filter((i) => i.status === 'TRANSMITTED').length;
    const queuedRetry = invs.filter((i) => i.status === 'QUEUED_RETRY').length;
    const rejected = invs.filter((i) => i.status === 'REJECTED').length;
    const totalSales = round2(
      invs
        .filter((i) => i.direction === 'SALES' && i.payload.DocType !== '03')
        .reduce((s, i) => s + i.payload.Summary.NetSales, 0),
    );
    const totalOutputVat = round2(
      invs
        .filter((i) => i.direction === 'SALES' && i.payload.DocType !== '03')
        .reduce((s, i) => s + i.payload.Summary.VATAmt, 0),
    );
    const totalCwt = round2(
      invs.reduce((s, i) => s + i.payload.Summary.WithholdingTaxAmt, 0),
    );

    const bySource: Record<string, number> = {};
    for (const inv of invs) {
      bySource[inv.sourceSystem] = (bySource[inv.sourceSystem] ?? 0) + 1;
    }

    return {
      gatewayConfig: this.gateway.config,
      taxpayerCount: this.taxpayers.length,
      invoiceCounts: {
        total: invs.length,
        transmitted,
        queuedRetry,
        rejected,
      },
      financialsPhp: {
        totalSales,
        totalOutputVat,
        totalCwt,
      },
      bySource,
      auditChain: this.auditTrail.verifyIntegrity(),
      atcCatalog: Object.values(BIR_ATC_CATALOG),
    };
  }

  public generateSlsp(taxpayerId: string | undefined, kind: 'SALES' | 'PURCHASES', period = '202611') {
    const tp = this.getTaxpayerById(taxpayerId);
    const records = this.getInvoices(tp.id);
    const report = generateSlspReport(tp, records, kind, period);
    this.auditTrail.append({
      actor: 'tax.accountant',
      action: `EXPORT_SLSP_${kind}`,
      taxpayerTin: tp.tin,
      entityType: 'StatutoryReport',
      entityId: report.filename,
      details: `Generated BIR RELIEF SLSP (${kind}) ${report.filename} with ${report.rowCount} record(s).`,
    });
    this.saveToDisk();
    return report;
  }

  public generateWithholdingDat(
    taxpayerId: string | undefined,
    kind: 'SAWT' | 'QAP',
    period = '202612',
  ) {
    const tp = this.getTaxpayerById(taxpayerId);
    const records = this.getInvoices(tp.id);
    const report = generateWithholdingDatReport(tp, records, kind, period);
    this.auditTrail.append({
      actor: 'tax.accountant',
      action: `EXPORT_${kind}_DAT`,
      taxpayerTin: tp.tin,
      entityType: 'StatutoryReport',
      entityId: report.filename,
      details: `Generated BIR ${kind} ${report.filename} with ${report.rowCount} record(s).`,
    });
    this.saveToDisk();
    return report;
  }

  public generateForm2307ForInvoice(invoiceId: string): BirForm2307Payload {
    const inv = this.invoices.find((i) => i.id === invoiceId);
    if (!inv) {
      throw new Error(`Invoice ${invoiceId} not found.`);
    }
    return generateBirForm2307(inv);
  }

  public setGatewayConfig(patch: Partial<{ mode: BirGatewayMode; simulateOutage: boolean }>) {
    if (patch.mode) {
      this.gateway.config.mode = patch.mode;
    }
    if (typeof patch.simulateOutage === 'boolean') {
      this.gateway.config.simulateOutage = patch.simulateOutage;
    }
    const tp = this.taxpayers[0];
    if (tp) {
      this.auditTrail.append({
        actor: 'system.admin',
        action: 'UPDATE_BIR_GATEWAY',
        taxpayerTin: tp.tin,
        entityType: 'GatewayConfig',
        entityId: this.gateway.config.mode,
        details: `Gateway Mode=${this.gateway.config.mode}, SimulateOutage=${this.gateway.config.simulateOutage}`,
      });
    }
    this.saveToDisk();
    return this.gateway.config;
  }

  /**
   * Seeds realistic Philippine transactions on initial startup so the UI and APIs are immediately rich.
   */
  public async seedDefaultDemoDataIfEmpty(): Promise<void> {
    if (this.taxpayers.length > 0) return;

    const tp = this.registerTaxpayer({
      tin: '009123456',
      taxType: 'VAT',
      registeredName: 'Mabuhay Tech & Solutions Inc.',
      businessName: 'Mabuhay Tech PH',
      email: 'compliance@mabuhaytech.ph',
      eisCertId: 'EISC2026',
      pttNumber: 'PTT-RDO044-2026-0881',
      headOfficeAddress: {
        Street: '24F Ayala Tower One, Ayala Ave',
        Barangay: 'Bel-Air',
        City: 'Makati City',
        Province: 'Metro Manila',
        ZipCode: '1226',
      },
    });

    this.addBranch(tp.id, {
      branchCd: '0001',
      branchName: 'BGC Bonifacio High Street POS Branch',
      address: {
        Street: '9th Ave cor High Street',
        Barangay: 'Fort Bonifacio',
        City: 'Taguig City',
        Province: 'Metro Manila',
        ZipCode: '1634',
      },
    });

    // 1. Standard B2B VATable + CWT (WC160 2%) from Built-in UI
    await this.ingestAndTransmitInvoice({
      taxpayerId: tp.id,
      branchCd: '0000',
      sourceSystem: 'IES_UI',
      systemType: 'CAS',
      docType: '02',
      transClass: 'B2B',
      buyerName: 'Bayanihan Retail Holdings Corp.',
      buyerTin: '008445566',
      buyerBranchCd: '0000',
      buyerAddress: {
        Street: 'Ortigas Center, Emerald Ave',
        Barangay: 'San Antonio',
        City: 'Pasig City',
        Province: 'Metro Manila',
        ZipCode: '1605',
      },
      items: [
        {
          itemCd: 'SRV-ERP-01',
          itemNm: 'Annual BIR CAS & EIS Integration Retainer',
          unit: 'LOT',
          qty: 1,
          unitPrice: 120000,
          taxClassification: 'VATABLE',
          atcCode: 'WC160',
        },
      ],
    });

    // 2. Senior Citizen POS Sale (RR 7-2024 VAT-Exempt + 20% Statutory Discount)
    await this.ingestAndTransmitInvoice({
      taxpayerId: tp.id,
      branchCd: '0001',
      sourceSystem: 'IES_UI',
      systemType: 'POS',
      docType: '01',
      transClass: 'B2C',
      isPaid: true,
      buyerName: 'Juanita Dela Cruz',
      buyerCategory: 'SENIOR_CITIZEN',
      osacaPwdId: 'OSCA-MAKATI-88412',
      items: [
        {
          itemCd: 'MED-DEV-02',
          itemNm: 'Ergonomic Wellness & Assistive Terminal',
          unit: 'PCS',
          qty: 1,
          unitPrice: 5600,
          priceIncludesVat: true,
          taxClassification: 'VATABLE',
        },
      ],
    });

    // 3. Export Zero-Rated Service synced from Xero
    await this.ingestFromXero(
      {
        InvoiceID: 'xero-inv-9001',
        InvoiceNumber: 'XERO-2026-104',
        Type: 'ACCREC',
        Status: 'AUTHORISED',
        Contact: {
          Name: 'Pacific Rim Logistics Pte Ltd (PEZA Zero-Rated)',
          TaxNumber: '007778899',
          Addresses: [
            { AddressLine1: 'Laguna Technopark', City: 'Biñan', Region: 'Laguna', PostalCode: '4024' },
          ],
        },
        LineItems: [
          {
            ItemCode: 'CLOUD-EXPORT',
            Description: 'Cross-border Cloud Data Engineering',
            Quantity: 1,
            UnitAmount: 85000,
            TaxType: 'ZERORATEDOUTPUT',
          },
        ],
      },
      tp.id,
    );

    // 4. Vendor Purchase Bill synced from QuickBooks Online (triggers Purchase Journal + QAP/2307)
    await this.ingestFromQuickBooks(
      {
        Id: 'qbo-bill-442',
        DocNumber: 'QBO-BILL-2026-77',
        TxnType: 'Bill',
        CustomerRef: { name: 'Rizal Cloud Infrastructure Inc.', tin: '006554433', branchCd: '0000' },
        Line: [
          {
            Description: 'Dedicated PH Server Hosting (BIR Static IP Egress)',
            SalesItemLineDetail: {
              ItemRef: { value: 'HOST-PH', name: 'Dedicated Server' },
              Qty: 1,
              UnitPrice: 25000,
              TaxCodeRef: { value: 'VAT12' },
              AtcCode: 'WC160',
            },
          },
        ],
      },
      tp.id,
    );

    // 5. Odoo l10n_ph Service Invoice
    await this.ingestFromOdoo(
      {
        id: 7021,
        name: 'INV/2026/0019',
        move_type: 'out_invoice',
        partner_id: {
          name: 'Cebu Harbor Trading Corp.',
          vat: '005332211',
          street: 'SRP Coastal Road',
          city: 'Cebu City',
          zip: '6000',
        },
        invoice_line_ids: [
          {
            product_code: 'ODOO-LIC',
            name: 'Enterprise POS Terminal Subscription',
            quantity: 5,
            price_unit: 4500,
            tax_ids: ['VAT_12'],
            l10n_ph_atc: 'WC160',
          },
        ],
      },
      tp.id,
    );
  }
}
