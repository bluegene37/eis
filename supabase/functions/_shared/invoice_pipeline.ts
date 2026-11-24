// Gene - Nov, 24, 2026: End-to-end BIR EIS v2.01 invoice ingestion, key vault signing,
// CAS 6-book posting, Annex B audit logging, and 3-day SLA retry pipeline.
import type { SupabaseClient } from '@supabase/supabase-js';
import {
  loadWorkspaceGatewayConfig,
  transmitEnvelope,
} from './bir_gateway.ts';
import {
  type BirEisPayloadV201,
  buildEisUniqueId,
  type CanonicalIngestInput,
  computeBirTaxBreakdown,
  formatBirDateTime,
  normalizeAddress,
  normalizeBranchCd,
  normalizeTin9,
} from './bir_tax.ts';
import { createJournalEntriesForInvoice } from './cas_books.ts';
import {
  type AesGcmEnvelope,
  decryptVaultSecret,
  encryptJwsWithAes256,
  encryptVaultSecret,
  generateTaxpayerCryptoBundle,
  signBirPayloadJws,
} from './vault.ts';

interface ReservedSequenceRow {
  workspace_id: string;
  taxpayer_id: string;
  tin: string;
  tax_type: string;
  registered_name: string;
  business_name: string;
  email: string;
  eis_cert_id: string;
  ptt_number: string;
  key_id: string;
  public_key_json: string;
  new_eis_sequence: number;
  branch_cd: string;
  branch_name: string;
  branch_address: Record<string, unknown>;
  invoice_prefix: string;
  new_branch_sequence: number;
}

interface TaxpayerSecretRow {
  taxpayer_id: string;
  workspace_id: string;
  key_id: string;
  encrypted_private_key_jwk: string;
  encrypted_aes_key_hex: string;
  key_version: number;
}

export async function appendAuditEntry(
  serviceClient: SupabaseClient,
  params: {
    workspaceId: string;
    actorId: string | null;
    actor: string;
    action: string;
    taxpayerTin: string;
    entityType: string;
    entityId: string;
    details: string;
  },
): Promise<void> {
  const { error } = await serviceClient.rpc('append_audit_entry', {
    p_workspace_id: params.workspaceId,
    p_actor_id: params.actorId,
    p_actor: params.actor,
    p_action: params.action,
    p_taxpayer_tin: params.taxpayerTin,
    p_entity_type: params.entityType,
    p_entity_id: params.entityId,
    p_details: params.details,
  });
  if (error) {
    throw new Error(`Failed to append Annex B audit entry: ${error.message}`);
  }
}

export async function registerTaxpayerWithKeys(
  serviceClient: SupabaseClient,
  params: {
    workspaceId: string;
    actorId: string | null;
    actor: string;
    tin: string;
    taxType?: string;
    registeredName: string;
    businessName: string;
    email: string;
    eisCertId?: string | null;
    pttNumber?: string | null;
    headOfficeAddress?: Record<string, unknown> | null;
  },
): Promise<Record<string, unknown>> {
  const normTin = normalizeTin9(params.tin);
  const rawCert = params.eisCertId?.trim() ?? '';
  const cert =
    rawCert.length > 0
      ? rawCert.toUpperCase().slice(0, 8)
      : `EC${normTin.slice(0, 6)}`;
  const ptt =
    params.pttNumber?.trim() && params.pttNumber.trim().length > 0
      ? params.pttNumber.trim()
      : `PTT-2026-${normTin.slice(-4)}`;
  const address = normalizeAddress(params.headOfficeAddress);

  const bundle = await generateTaxpayerCryptoBundle(normTin, cert);
  const encPrivate = await encryptVaultSecret(bundle.privateKeyJson);
  const encAes = await encryptVaultSecret(bundle.aesKeyHex);

  const { data: tp, error: tpErr } = await serviceClient
    .from('taxpayers')
    .insert({
      workspace_id: params.workspaceId,
      tin: normTin,
      tax_type: params.taxType === 'NON_VAT' ? 'NON_VAT' : 'VAT',
      registered_name: params.registeredName.trim(),
      business_name: params.businessName.trim(),
      email: params.email.trim(),
      eis_cert_id: cert,
      ptt_number: ptt,
      key_id: bundle.keyId,
      public_key_json: bundle.publicKeyJson,
      last_eis_sequence: 0,
    })
    .select('*')
    .single();

  if (tpErr || !tp) {
    throw new Error(`Failed to register taxpayer: ${tpErr?.message}`);
  }

  const { data: branch, error: brErr } = await serviceClient
    .from('taxpayer_branches')
    .insert({
      workspace_id: params.workspaceId,
      taxpayer_id: tp.id,
      branch_cd: '0000',
      branch_name: 'Head Office',
      address,
      last_sequence: 0,
      invoice_prefix: 'SI-0000',
    })
    .select('*')
    .single();

  if (brErr || !branch) {
    throw new Error(`Failed to create Head Office branch: ${brErr?.message}`);
  }

  const { error: secErr } = await serviceClient.rpc('upsert_taxpayer_secret', {
    p_taxpayer_id: tp.id,
    p_workspace_id: params.workspaceId,
    p_key_id: bundle.keyId,
    p_encrypted_private_key_jwk: encPrivate,
    p_encrypted_aes_key_hex: encAes,
    p_increment_version: false,
  });

  if (secErr) {
    throw new Error(`Failed to store taxpayer vault secret: ${secErr.message}`);
  }

  await appendAuditEntry(serviceClient, {
    workspaceId: params.workspaceId,
    actorId: params.actorId,
    actor: params.actor,
    action: 'REGISTER_TAXPAYER_TIN',
    taxpayerTin: normTin,
    entityType: 'TaxpayerProfile',
    entityId: String(tp.id),
    details: `Registered ${tp.registered_name} (TIN ${normTin}, Cert ${cert}, RSA-2048 + AES-256 keys provisioned in private vault).`,
  });

  return {
    id: tp.id,
    workspaceId: tp.workspace_id,
    tin: tp.tin,
    taxType: tp.tax_type,
    registeredName: tp.registered_name,
    businessName: tp.business_name,
    email: tp.email,
    eisCertId: tp.eis_cert_id,
    pttNumber: tp.ptt_number,
    keyId: tp.key_id,
    publicKeyPem: tp.public_key_json,
    branches: [
      {
        branchCd: branch.branch_cd,
        branchName: branch.branch_name,
        address: branch.address,
        lastSequence: Number(branch.last_sequence),
        invoicePrefix: branch.invoice_prefix,
      },
    ],
  };
}

export async function addTaxpayerBranch(
  serviceClient: SupabaseClient,
  params: {
    workspaceId: string;
    taxpayerId: string;
    actorId: string | null;
    actor: string;
    branchCd: string;
    branchName: string;
    address?: Record<string, unknown> | null;
    invoicePrefix?: string | null;
  },
): Promise<Record<string, unknown>> {
  const normCd = normalizeBranchCd(params.branchCd);
  const { data: tp, error: tpErr } = await serviceClient
    .from('taxpayers')
    .select('id, tin, workspace_id')
    .eq('id', params.taxpayerId)
    .eq('workspace_id', params.workspaceId)
    .maybeSingle();

  if (tpErr || !tp) {
    throw new Error('Taxpayer not found in workspace.');
  }

  const prefix =
    params.invoicePrefix?.trim() && params.invoicePrefix.trim().length > 0
      ? params.invoicePrefix.trim()
      : `SI-${normCd}`;

  const { data: branch, error: brErr } = await serviceClient
    .from('taxpayer_branches')
    .insert({
      workspace_id: params.workspaceId,
      taxpayer_id: tp.id,
      branch_cd: normCd,
      branch_name: params.branchName.trim(),
      address: normalizeAddress(params.address),
      last_sequence: 0,
      invoice_prefix: prefix,
    })
    .select('*')
    .single();

  if (brErr || !branch) {
    throw new Error(`Failed to add branch: ${brErr?.message}`);
  }

  await appendAuditEntry(serviceClient, {
    workspaceId: params.workspaceId,
    actorId: params.actorId,
    actor: params.actor,
    action: 'ADD_BRANCH',
    taxpayerTin: String(tp.tin),
    entityType: 'TaxpayerBranch',
    entityId: normCd,
    details: `Added Branch ${normCd} (${branch.branch_name}) under TIN ${tp.tin}.`,
  });

  return {
    branchCd: branch.branch_cd,
    branchName: branch.branch_name,
    address: branch.address,
    lastSequence: Number(branch.last_sequence),
    invoicePrefix: branch.invoice_prefix,
  };
}

export async function rotateTaxpayerVaultKeys(
  serviceClient: SupabaseClient,
  params: {
    workspaceId: string;
    taxpayerId: string;
    actorId: string | null;
    actor: string;
  },
): Promise<Record<string, unknown>> {
  const { data: tp, error: tpErr } = await serviceClient
    .from('taxpayers')
    .select('id, tin, eis_cert_id, workspace_id')
    .eq('id', params.taxpayerId)
    .eq('workspace_id', params.workspaceId)
    .maybeSingle();

  if (tpErr || !tp) {
    throw new Error('Taxpayer not found in workspace.');
  }

  const bundle = await generateTaxpayerCryptoBundle(
    String(tp.tin),
    String(tp.eis_cert_id),
  );
  const encPrivate = await encryptVaultSecret(bundle.privateKeyJson);
  const encAes = await encryptVaultSecret(bundle.aesKeyHex);

  const { error: updErr } = await serviceClient
    .from('taxpayers')
    .update({
      key_id: bundle.keyId,
      public_key_json: bundle.publicKeyJson,
    })
    .eq('id', tp.id)
    .eq('workspace_id', params.workspaceId);

  if (updErr) {
    throw new Error(`Failed to update taxpayer public key: ${updErr.message}`);
  }

  const { error: secErr } = await serviceClient.rpc('upsert_taxpayer_secret', {
    p_taxpayer_id: tp.id,
    p_workspace_id: params.workspaceId,
    p_key_id: bundle.keyId,
    p_encrypted_private_key_jwk: encPrivate,
    p_encrypted_aes_key_hex: encAes,
    p_increment_version: true,
  });

  if (secErr) {
    throw new Error(`Failed to rotate taxpayer vault secret: ${secErr.message}`);
  }

  await appendAuditEntry(serviceClient, {
    workspaceId: params.workspaceId,
    actorId: params.actorId,
    actor: params.actor,
    action: 'ROTATE_JWS_AES_KEYS',
    taxpayerTin: String(tp.tin),
    entityType: 'TaxpayerProfile',
    entityId: String(tp.id),
    details: `Rotated RSA-2048 JWS keypair (${bundle.keyId}) and AES-256 key.`,
  });

  return {
    id: tp.id,
    keyId: bundle.keyId,
    publicKeyPem: bundle.publicKeyJson,
  };
}

async function resolveTaxpayerId(
  serviceClient: SupabaseClient,
  workspaceId: string,
  requestedTaxpayerId?: string | null,
): Promise<string> {
  if (requestedTaxpayerId && requestedTaxpayerId.trim().length > 0) {
    const { data, error } = await serviceClient
      .from('taxpayers')
      .select('id')
      .eq('id', requestedTaxpayerId.trim())
      .eq('workspace_id', workspaceId)
      .maybeSingle();
    if (error || !data) {
      throw new Error('Taxpayer profile not found in workspace.');
    }
    return String(data.id);
  }

  const { data, error } = await serviceClient
    .from('taxpayers')
    .select('id')
    .eq('workspace_id', workspaceId)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle();
  if (error || !data) {
    throw new Error('No Taxpayer TIN registered in workspace yet.');
  }
  return String(data.id);
}

async function loadDecryptedTaxpayerSecret(
  serviceClient: SupabaseClient,
  taxpayerId: string,
): Promise<{ privateKeyJson: string; aesKeyHex: string }> {
  const { data, error } = await serviceClient.rpc('get_taxpayer_secret', {
    p_taxpayer_id: taxpayerId,
  });
  const row = Array.isArray(data)
    ? (data[0] as TaxpayerSecretRow | undefined)
    : (data as TaxpayerSecretRow | null);
  if (error || !row) {
    throw new Error(
      `Taxpayer secret missing from vault: ${error?.message ?? taxpayerId}`,
    );
  }
  return {
    privateKeyJson: await decryptVaultSecret(row.encrypted_private_key_jwk),
    aesKeyHex: await decryptVaultSecret(row.encrypted_aes_key_hex),
  };
}

export function serializeInvoiceRow(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: row['id'],
    taxpayerId: row['taxpayer_id'],
    branchCd: row['branch_cd'],
    sourceSystem: row['source_system'],
    externalRefId: row['external_ref_id'],
    direction: row['direction'],
    isPaid: row['is_paid'],
    payload: row['payload'],
    jwsToken: row['jws_token'],
    aesEnvelope: row['aes_envelope'],
    status: row['status'],
    retryCount: Number(row['retry_count'] ?? 0),
    nextRetryAt: row['next_retry_at'],
    threeDayDeadlineAt: row['three_day_deadline_at'],
    lastReceipt: row['last_receipt'],
    createdAt: row['created_at'],
  };
}

export async function ingestAndTransmitInvoice(
  serviceClient: SupabaseClient,
  params: {
    workspaceId: string;
    actorId: string | null;
    actor: string;
    input: CanonicalIngestInput;
    forceInvalidPayload?: boolean;
  },
): Promise<Record<string, unknown>> {
  const { workspaceId, actorId, actor, input } = params;
  const targetTaxpayerId = await resolveTaxpayerId(
    serviceClient,
    workspaceId,
    input.taxpayerId,
  );

  const normBranch = normalizeBranchCd(input.branchCd);
  const { data: seqData, error: seqErr } = await serviceClient.rpc(
    'reserve_invoice_sequences',
    {
      p_taxpayer_id: targetTaxpayerId,
      p_branch_cd: normBranch,
    },
  );
  const seqRow = Array.isArray(seqData)
    ? (seqData[0] as ReservedSequenceRow | undefined)
    : (seqData as ReservedSequenceRow | null);
  if (seqErr || !seqRow) {
    throw new Error(
      `Failed to reserve gapless BIR invoice sequence: ${seqErr?.message ?? 'unknown'}`,
    );
  }

  const parsedIssue = input.issueDtm ? new Date(input.issueDtm) : null;
  const issueDate =
    parsedIssue && !Number.isNaN(parsedIssue.getTime())
      ? parsedIssue
      : new Date();

  const eisUniqueId = buildEisUniqueId(
    issueDate,
    seqRow.eis_cert_id,
    Number(seqRow.new_eis_sequence),
  );
  const compInvoiceId =
    input.compInvoiceId && input.compInvoiceId.trim().length > 0
      ? input.compInvoiceId.trim()
      : `${seqRow.invoice_prefix}-${Number(seqRow.new_branch_sequence).toString().padStart(6, '0')}`;

  const computed = computeBirTaxBreakdown(input.items, seqRow.tax_type, {
    buyerCategory: input.buyerCategory,
    otherChargesAmt: input.otherChargesAmt,
  });

  const normBuyerTin =
    input.buyerTin && input.buyerTin.trim().length > 0
      ? normalizeTin9(input.buyerTin)
      : null;

  const payload: BirEisPayloadV201 = {
    SchemaVer: 'v2.01',
    SystemType: input.systemType,
    EisUniqueId: eisUniqueId,
    CompInvoiceId: compInvoiceId,
    IssueDtm: formatBirDateTime(issueDate),
    DocType: input.docType,
    TransClass: input.transClass ?? (normBuyerTin ? 'B2B' : 'B2C'),
    CorrYN:
      input.corrYN ??
      (input.docType === '03' || input.docType === '04' ? 'Y' : 'N'),
    RefEisUniqueId: input.refEisUniqueId ?? null,
    Currency: 'PHP',
    Seller: {
      TIN: seqRow.tin,
      BranchCd: seqRow.branch_cd,
      Type: seqRow.tax_type,
      RegNm: seqRow.registered_name,
      BusinessNm: seqRow.business_name,
      Address: normalizeAddress(seqRow.branch_address),
      Email: seqRow.email,
    },
    Buyer: {
      TIN: params.forceInvalidPayload ? null : normBuyerTin,
      BranchCd: normBuyerTin ? normalizeBranchCd(input.buyerBranchCd) : null,
      RegNm: input.buyerName.trim(),
      Address: input.buyerAddress ?? null,
      BuyerCategory: input.buyerCategory,
      OsacaPwdId: input.osacaPwdId ?? null,
    },
    ItemList: computed.itemList,
    Summary: computed.summary,
  };

  const secrets = await loadDecryptedTaxpayerSecret(
    serviceClient,
    seqRow.taxpayer_id,
  );
  const jwsToken = await signBirPayloadJws(
    payload,
    secrets.privateKeyJson,
    seqRow.key_id,
  );
  const aesEnvelope = await encryptJwsWithAes256(jwsToken, secrets.aesKeyHex);

  const gwConfig = await loadWorkspaceGatewayConfig(serviceClient, workspaceId);
  const receipt = await transmitEnvelope(serviceClient, gwConfig, aesEnvelope, {
    tin: seqRow.tin,
    eisCertId: seqRow.eis_cert_id,
    pttNumber: seqRow.ptt_number,
    publicKeyJson: seqRow.public_key_json,
    aesKeyHex: secrets.aesKeyHex,
  });

  const deadline = new Date(issueDate.getTime() + 3 * 24 * 60 * 60 * 1000);
  const status = receipt.accepted
    ? 'TRANSMITTED'
    : receipt.ackCode === 'NET503'
    ? 'QUEUED_RETRY'
    : 'REJECTED';
  const nextRetryAt =
    status === 'QUEUED_RETRY'
      ? new Date(Date.now() + 5 * 60 * 1000).toISOString()
      : null;

  const { data: insertedInv, error: invErr } = await serviceClient
    .from('invoices')
    .insert({
      workspace_id: workspaceId,
      taxpayer_id: seqRow.taxpayer_id,
      branch_cd: seqRow.branch_cd,
      eis_unique_id: eisUniqueId,
      comp_invoice_id: compInvoiceId,
      issue_dtm: payload.IssueDtm,
      doc_type: payload.DocType,
      trans_class: payload.TransClass,
      system_type: payload.SystemType,
      source_system: input.sourceSystem,
      external_ref_id: input.externalRefId ?? null,
      direction: input.direction,
      is_paid: input.isPaid,
      ref_eis_unique_id: payload.RefEisUniqueId,
      gross_sales_amt: computed.summary.GrossSalesAmt,
      total_discount_amt: computed.summary.TotalDiscountAmt,
      sc_pwd_discount_amt: computed.summary.ScPwdDiscountAmt,
      net_sales: computed.summary.NetSales,
      vatable_sales: computed.summary.VATableSales,
      vat_exempt_sales: computed.summary.VATExemptSales,
      zero_rated_sales: computed.summary.ZeroRatedSales,
      vat_amt: computed.summary.VATAmt,
      withholding_tax_amt: computed.summary.WithholdingTaxAmt,
      other_charges_amt: computed.summary.OtherChargesAmt,
      total_amount_due: computed.summary.TotalAmountDue,
      payload,
      jws_token: jwsToken,
      aes_envelope: aesEnvelope,
      status,
      retry_count: status === 'QUEUED_RETRY' ? 1 : 0,
      next_retry_at: nextRetryAt,
      three_day_deadline_at: deadline.toISOString(),
      last_receipt: receipt,
      created_by: actorId,
    })
    .select('*')
    .single();

  if (invErr || !insertedInv) {
    throw new Error(`Failed to persist invoice: ${invErr?.message}`);
  }

  if (status !== 'REJECTED') {
    const journalDrafts = createJournalEntriesForInvoice({
      direction: input.direction,
      isPaid: input.isPaid,
      sourceSystem: input.sourceSystem,
      payload,
    });

    for (const draft of journalDrafts) {
      const { data: jeRow, error: jeErr } = await serviceClient
        .from('cas_journal_entries')
        .insert({
          workspace_id: workspaceId,
          taxpayer_id: seqRow.taxpayer_id,
          invoice_id: insertedInv.id,
          branch_cd: seqRow.branch_cd,
          book_type: draft.bookType,
          entry_date: draft.entryDate,
          reference_no: draft.referenceNo,
          eis_unique_id: draft.eisUniqueId,
          counterparty_name: draft.counterpartyName,
          counterparty_tin: draft.counterpartyTin,
          particulars: draft.particulars,
          total_debit: draft.totalDebit,
          total_credit: draft.totalCredit,
          created_by: actorId,
        })
        .select('id')
        .single();

      if (jeErr || !jeRow) {
        throw new Error(`Failed to post CAS journal entry: ${jeErr?.message}`);
      }

      if (draft.lines.length > 0) {
        const lineRows = draft.lines.map((ln, idx) => ({
          workspace_id: workspaceId,
          journal_entry_id: jeRow.id,
          line_no: idx + 1,
          account_code: ln.accountCode,
          account_name: ln.accountName,
          debit: ln.debit,
          credit: ln.credit,
        }));
        const { error: lineErr } = await serviceClient
          .from('cas_journal_lines')
          .insert(lineRows);
        if (lineErr) {
          throw new Error(`Failed to post CAS journal lines: ${lineErr.message}`);
        }
      }
    }
  }

  await appendAuditEntry(serviceClient, {
    workspaceId,
    actorId,
    actor,
    action: `EIS_INGEST_${status}`,
    taxpayerTin: seqRow.tin,
    entityType: 'Invoice',
    entityId: eisUniqueId,
    details: `${compInvoiceId} | ${receipt.ackCode} | NetSales PHP ${computed.summary.NetSales.toFixed(2)} | VAT PHP ${computed.summary.VATAmt.toFixed(2)} | CWT PHP ${computed.summary.WithholdingTaxAmt.toFixed(2)}`,
  });

  return serializeInvoiceRow(insertedInv as Record<string, unknown>);
}

export async function processWorkspaceRetryQueue(
  serviceClient: SupabaseClient,
  params: {
    workspaceId?: string | null;
    actorId?: string | null;
    actor?: string;
    dueOnly?: boolean;
  },
): Promise<{ processed: number; succeeded: number; stillQueued: number }> {
  let query = serviceClient
    .from('invoices')
    .select(
      'id, workspace_id, taxpayer_id, eis_unique_id, aes_envelope, retry_count, next_retry_at',
    )
    .eq('status', 'QUEUED_RETRY')
    .order('created_at', { ascending: true });

  if (params.workspaceId) {
    query = query.eq('workspace_id', params.workspaceId);
  }
  if (params.dueOnly) {
    query = query.lte('next_retry_at', new Date().toISOString());
  }

  const { data: queued, error } = await query.limit(100);
  if (error) {
    throw new Error(`Failed to query retry queue: ${error.message}`);
  }

  const rows = queued ?? [];
  let succeeded = 0;
  let stillQueued = 0;

  for (const inv of rows) {
    const wsId = String(inv.workspace_id);
    const tpId = String(inv.taxpayer_id);

    const { data: tp } = await serviceClient
      .from('taxpayers')
      .select('tin, eis_cert_id, ptt_number, public_key_json')
      .eq('id', tpId)
      .single();

    if (!tp) continue;
    const secrets = await loadDecryptedTaxpayerSecret(serviceClient, tpId);
    const gwConfig = await loadWorkspaceGatewayConfig(serviceClient, wsId);

    const receipt = await transmitEnvelope(
      serviceClient,
      gwConfig,
      inv.aes_envelope as AesGcmEnvelope,
      {
        tin: String(tp.tin),
        eisCertId: String(tp.eis_cert_id),
        pttNumber: String(tp.ptt_number),
        publicKeyJson: String(tp.public_key_json),
        aesKeyHex: secrets.aesKeyHex,
      },
      { allowDuplicateCheck: false },
    );

    const nextCount = Number(inv.retry_count ?? 0) + 1;
    let nextStatus = 'REJECTED';
    let nextRetryAt: string | null = null;

    if (receipt.accepted) {
      nextStatus = 'TRANSMITTED';
      succeeded += 1;
    } else if (receipt.ackCode === 'NET503') {
      nextStatus = 'QUEUED_RETRY';
      const backoffMin = Math.min(60, 5 * Math.pow(2, Math.min(4, nextCount - 1)));
      nextRetryAt = new Date(Date.now() + backoffMin * 60 * 1000).toISOString();
      stillQueued += 1;
    }

    await serviceClient
      .from('invoices')
      .update({
        status: nextStatus,
        retry_count: nextCount,
        next_retry_at: nextRetryAt,
        last_receipt: receipt,
        updated_at: new Date().toISOString(),
      })
      .eq('id', inv.id);

    if (nextStatus === 'TRANSMITTED') {
      await appendAuditEntry(serviceClient, {
        workspaceId: wsId,
        actorId: params.actorId ?? null,
        actor: params.actor ?? 'worker.retry_queue',
        action: 'EIS_RETRY_TRANSMITTED',
        taxpayerTin: String(tp.tin),
        entityType: 'Invoice',
        entityId: String(inv.eis_unique_id),
        details: `Recovered via 3-day SLA queue on attempt #${nextCount}: ${receipt.birAckId}`,
      });
    }
  }

  return {
    processed: rows.length,
    succeeded,
    stillQueued,
  };
}

export async function seedDemoDataForWorkspace(
  serviceClient: SupabaseClient,
  params: {
    workspaceId: string;
    actorId: string | null;
    actor: string;
  },
): Promise<void> {
  const { count } = await serviceClient
    .from('taxpayers')
    .select('id', { count: 'exact', head: true })
    .eq('workspace_id', params.workspaceId);
  if ((count ?? 0) > 0) return;

  const tp = await registerTaxpayerWithKeys(serviceClient, {
    workspaceId: params.workspaceId,
    actorId: params.actorId,
    actor: params.actor,
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

  const taxpayerId = String(tp['id']);

  await addTaxpayerBranch(serviceClient, {
    workspaceId: params.workspaceId,
    taxpayerId,
    actorId: params.actorId,
    actor: params.actor,
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

  const demoInputs: CanonicalIngestInput[] = [
    {
      taxpayerId,
      branchCd: '0000',
      sourceSystem: 'IES_UI',
      systemType: 'CAS',
      docType: '02',
      transClass: 'B2B',
      direction: 'SALES',
      isPaid: false,
      buyerName: 'Bayanihan Retail Holdings Corp.',
      buyerTin: '008445566',
      buyerBranchCd: '0000',
      buyerCategory: 'REGULAR',
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
      otherChargesAmt: 0,
    },
    {
      taxpayerId,
      branchCd: '0001',
      sourceSystem: 'IES_UI',
      systemType: 'POS',
      docType: '01',
      transClass: 'B2C',
      direction: 'SALES',
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
      otherChargesAmt: 0,
    },
    {
      taxpayerId,
      branchCd: '0000',
      sourceSystem: 'XERO',
      externalRefId: 'xero-inv-9001',
      compInvoiceId: 'XERO-2026-104',
      systemType: 'CAS',
      docType: '01',
      transClass: 'B2B',
      direction: 'SALES',
      isPaid: false,
      buyerName: 'Pacific Rim Logistics Pte Ltd (PEZA Zero-Rated)',
      buyerTin: '007778899',
      buyerBranchCd: '0000',
      buyerCategory: 'REGULAR',
      buyerAddress: {
        Street: 'Laguna Technopark',
        Barangay: 'N/A',
        City: 'Biñan',
        Province: 'Laguna',
        ZipCode: '4024',
      },
      items: [
        {
          itemCd: 'CLOUD-EXPORT',
          itemNm: 'Cross-border Cloud Data Engineering',
          unit: 'PCS',
          qty: 1,
          unitPrice: 85000,
          taxClassification: 'ZERO_RATED',
        },
      ],
      otherChargesAmt: 0,
    },
    {
      taxpayerId,
      branchCd: '0000',
      sourceSystem: 'QUICKBOOKS',
      externalRefId: 'qbo-bill-442',
      compInvoiceId: 'QBO-BILL-2026-77',
      systemType: 'CAS',
      docType: '01',
      transClass: 'B2B',
      direction: 'PURCHASE',
      isPaid: false,
      buyerName: 'Rizal Cloud Infrastructure Inc.',
      buyerTin: '006554433',
      buyerBranchCd: '0000',
      buyerCategory: 'REGULAR',
      items: [
        {
          itemCd: 'HOST-PH',
          itemNm: 'Dedicated PH Server Hosting (BIR Static IP Egress)',
          unit: 'PCS',
          qty: 1,
          unitPrice: 25000,
          taxClassification: 'VATABLE',
          atcCode: 'WC160',
        },
      ],
      otherChargesAmt: 0,
    },
    {
      taxpayerId,
      branchCd: '0000',
      sourceSystem: 'ODOO',
      externalRefId: '7021',
      compInvoiceId: 'INV/2026/0019',
      systemType: 'CAS',
      docType: '02',
      transClass: 'B2B',
      direction: 'SALES',
      isPaid: false,
      buyerName: 'Cebu Harbor Trading Corp.',
      buyerTin: '005332211',
      buyerBranchCd: '0000',
      buyerCategory: 'REGULAR',
      buyerAddress: {
        Street: 'SRP Coastal Road',
        Barangay: 'N/A',
        City: 'Cebu City',
        Province: 'Metro Manila',
        ZipCode: '6000',
      },
      items: [
        {
          itemCd: 'ODOO-LIC',
          itemNm: 'Enterprise POS Terminal Subscription',
          unit: 'PCS',
          qty: 5,
          unitPrice: 4500,
          taxClassification: 'VATABLE',
          atcCode: 'WC160',
        },
      ],
      otherChargesAmt: 0,
    },
  ];

  for (const item of demoInputs) {
    await ingestAndTransmitInvoice(serviceClient, {
      workspaceId: params.workspaceId,
      actorId: params.actorId,
      actor: params.actor,
      input: item,
    });
  }
}
