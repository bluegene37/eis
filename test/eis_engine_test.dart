// Gene - Nov, 20, 2026: Ported pure-Dart BIR EIS v2.01 & CAS engine test suite from eis and added local JSON persistence roundtrip verification.
import 'dart:convert';
import 'dart:io';
// import 'package:eis_v2/core/bir/bir_eis_schema.dart';
// import 'package:eis_v2/core/bir/crypto_jws_aes_service.dart';
// import 'package:eis_v2/core/bir/eis_engine_service.dart';
// import 'package:eis_v2/core/bir/erp_connectors_service.dart';
// import 'package:eis_v2/core/bir/tax_calculator_service.dart';
// Gene - Nov, 20, 2026: Updated package imports from eis_v2 to eis.
import 'package:eis/core/bir/bir_eis_schema.dart';
import 'package:eis/core/bir/crypto_jws_aes_service.dart';
import 'package:eis/core/bir/eis_engine_service.dart';
import 'package:eis/core/bir/erp_connectors_service.dart';
import 'package:eis/core/bir/tax_calculator_service.dart';
import 'package:flutter_test/flutter_test.dart';

EisEngineService _createTestEngine({String? persistPath}) {
  final engine = EisEngineService(persistPath: persistPath);
  engine.registerTaxpayer(
    tin: '009123456',
    taxType: 'VAT',
    registeredName: 'Test Manila Corp.',
    businessName: 'Test Manila',
    email: 'tax@testmanila.ph',
    eisCertId: 'EISC2026',
    headOfficeAddress: const BirAddress(
      street: '123 Ayala Ave',
      barangay: 'Bel-Air',
      city: 'Makati City',
      province: 'Metro Manila',
      zipCode: '1226',
    ),
  );
  return engine;
}

void main() {
  group('Pure-Dart BIR EIS v2.01 & CAS Compliance Engine', () {
    test('generates valid 24-character EisUniqueId and normalizes TIN', () {
      final id1 = buildEisUniqueId(
        DateTime.parse('2026-11-17T10:00:00'),
        'EISC2026',
        1,
      );
      final id2 = buildEisUniqueId(
        DateTime.parse('2026-11-17T10:05:00'),
        'EISC2026',
        2,
      );
      expect(id1, '20261117EISC202600000001');
      expect(id1.length, 24);
      expect(id2, '20261117EISC202600000002');
      expect(normalizeTin9('009-123-456-0000'), '009123456');
    });

    test(
        'computes EOPT RR 7-2024 VATable, SC VAT-Exempt + 20% Discount, Zero-Rated, and CWT ATC math',
        () {
      final b2b = computeBirTaxBreakdown(
        const [
          RawLineItemInput(
            itemNm: 'IT Consultancy',
            qty: 1,
            unitPrice: 100000,
            taxClassification: 'VATABLE',
            atcCode: 'WC160',
          ),
        ],
        'VAT',
      );
      expect(b2b.summary.vatableSales, 100000);
      expect(b2b.summary.vatAmt, 12000);
      expect(b2b.summary.withholdingTaxAmt, 2000);
      expect(b2b.summary.totalAmountDue, 110000);

      final sc = computeBirTaxBreakdown(
        const [
          RawLineItemInput(
            itemNm: 'Essential Medical Device',
            qty: 1,
            unitPrice: 1120,
            priceIncludesVat: true,
          ),
        ],
        'VAT',
        buyerCategory: 'SENIOR_CITIZEN',
      );
      expect(sc.summary.grossSalesAmt, 1000);
      expect(sc.summary.scPwdDiscountAmt, 200);
      expect(sc.summary.vatExemptSales, 800);
      expect(sc.summary.vatAmt, 0);
      expect(sc.summary.totalAmountDue, 800);

      final zr = computeBirTaxBreakdown(
        const [
          RawLineItemInput(
            itemNm: 'Export Software',
            qty: 2,
            unitPrice: 25000,
            taxClassification: 'ZERO_RATED',
          ),
        ],
        'VAT',
      );
      expect(zr.summary.zeroRatedSales, 50000);
      expect(zr.summary.vatAmt, 0);
      expect(zr.summary.totalAmountDue, 50000);
    });

    test(
        'signs JWS (RS256), detects tampering, and completes AES-256-GCM roundtrip via PointyCastle',
        () {
      final bundle = generateTaxpayerCryptoBundle('009123456', 'EISC2026');
      final sample = {
        'EisUniqueId': '20261117EISC202600000001',
        'NetSales': 1000,
      };

      final jws = signBirPayloadJws(sample, bundle.privateKeyJson, bundle.keyId);
      final envelope = encryptJwsWithAes256(jws, bundle.aesKeyHex);
      final decrypted = decryptAes256Envelope(envelope, bundle.aesKeyHex);
      expect(decrypted, jws);

      final verified = verifyBirPayloadJws(decrypted, bundle.publicKeyJson);
      expect(verified.valid, isTrue);
      expect(verified.payload?['NetSales'], 1000);

      final parts = decrypted.split('.');
      parts[1] = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'EisUniqueId': '20261117EISC202600000001',
                'NetSales': 999999,
              }),
            ),
          )
          .replaceAll('=', '');
      final tampered = verifyBirPayloadJws(parts.join('.'), bundle.publicKeyJson);
      expect(tampered.valid, isFalse);
    });

    test(
        'simulates BIR EIS ACK-200, SYN004, VAL001, DUP001, and 3-day retry queue outage recovery',
        () async {
      final engine = _createTestEngine();

      final ok = await engine.ingestAndTransmitInvoice(
        const CanonicalIngestInput(
          sourceSystem: 'IES_UI',
          transClass: 'B2B',
          buyerName: 'Ayala Buyer Corp',
          buyerTin: '008111222',
          items: [
            RawLineItemInput(itemNm: 'Cloud Platform', qty: 1, unitPrice: 10000),
          ],
        ),
      );
      expect(ok.status, 'TRANSMITTED');
      expect(ok.lastReceipt?.ackCode, 'ACK-200');
      expect(ok.payload.eisUniqueId.length, 24);

      // Verify multi-branch issuance under the same TIN generates distinct EisUniqueIds (no DUP001 collision).
      final tpForBranch = engine.getTaxpayerById();
      engine.addBranch(
        tpForBranch.id,
        branchCd: '0001',
        branchName: 'BGC POS Branch',
        address: const BirAddress(
          street: '9th Ave',
          barangay: 'Fort Bonifacio',
          city: 'Taguig City',
          province: 'Metro Manila',
          zipCode: '1634',
        ),
      );
      final branchSale = await engine.ingestAndTransmitInvoice(
        const CanonicalIngestInput(
          branchCd: '0001',
          sourceSystem: 'IES_UI',
          systemType: 'POS',
          transClass: 'B2C',
          buyerName: 'Branch Walk-in',
          items: [
            RawLineItemInput(itemNm: 'Branch Item', qty: 1, unitPrice: 1200),
          ],
        ),
      );
      expect(branchSale.status, 'TRANSMITTED');
      expect(branchSale.lastReceipt?.ackCode, 'ACK-200');
      expect(branchSale.payload.eisUniqueId, isNot(ok.payload.eisUniqueId));

      final synErr = await engine.ingestAndTransmitInvoice(
        const CanonicalIngestInput(
          sourceSystem: 'IES_UI',
          transClass: 'B2B',
          buyerName: 'Missing TIN Corp',
          buyerTin: '008111222',
          items: [
            RawLineItemInput(itemNm: 'Consulting', qty: 1, unitPrice: 5000),
          ],
        ),
        forceInvalidPayload: true,
      );
      expect(synErr.status, 'REJECTED');
      expect(synErr.lastReceipt?.ackCode, 'SYN004');

      final tp = engine.getTaxpayerById();
      final badMap = ok.payload.toJson();
      badMap['EisUniqueId'] = '20261117EISC202600000099';
      (badMap['Summary'] as Map<String, dynamic>)['VATAmt'] = 99999;
      final badJws = signBirPayloadJws(badMap, tp.privateKeyJson, tp.keyId);
      final badEnv = encryptJwsWithAes256(badJws, tp.aesKeyHex);
      final valResp = await engine.gateway.transmitEnvelope(badEnv, tp);
      expect(valResp.ackCode, 'VAL001');

      final dupResp =
          await engine.gateway.transmitEnvelope(ok.aesEnvelope, tp);
      expect(dupResp.ackCode, 'DUP001');

      engine.setGatewayConfig(simulateOutage: true);
      final queued = await engine.ingestAndTransmitInvoice(
        const CanonicalIngestInput(
          sourceSystem: 'IES_UI',
          transClass: 'B2C',
          buyerName: 'Walk-in Customer',
          items: [
            RawLineItemInput(itemNm: 'POS Retail Item', qty: 2, unitPrice: 500),
          ],
        ),
      );
      expect(queued.status, 'QUEUED_RETRY');
      expect(queued.lastReceipt?.ackCode, 'NET503');

      engine.setGatewayConfig(simulateOutage: false);
      final retryResult = await engine.processRetryQueue();
      expect(retryResult['processed'], 1);
      expect(retryResult['succeeded'], 1);

      final updated =
          engine.getInvoices().where((i) => i.id == queued.id).first;
      expect(updated.status, 'TRANSMITTED');
      expect(updated.lastReceipt?.ackCode, 'ACK-200');
    });

    test(
        'ingests Xero, QuickBooks, Odoo, and CSV into BIR v2.01, balanced CAS books, .DAT exports, and Annex B audit trail',
        () async {
      final engine = _createTestEngine();

      final xeroInv = await engine.ingestFromXero({
        'InvoiceID': 'xero-1',
        'InvoiceNumber': 'X-001',
        'Type': 'ACCREC',
        'Contact': {'Name': 'Xero PH Client', 'TaxNumber': '007111222'},
        'LineItems': [
          {
            'Description': 'SaaS Subscription',
            'Quantity': 1,
            'UnitAmount': 10000,
            'TaxType': 'OUTPUT',
            'AtcCode': 'WC160',
          },
        ],
      });
      expect(xeroInv.status, 'TRANSMITTED');
      expect(validateBirSchemaV201(xeroInv.payload), isEmpty);

      final qboBill = await engine.ingestFromQuickBooks({
        'Id': 'qbo-1',
        'DocNumber': 'Q-BILL-1',
        'TxnType': 'Bill',
        'CustomerRef': {'name': 'QBO PH Vendor', 'tin': '006222333'},
        'Line': [
          {
            'Description': 'Cloud Hosting',
            'SalesItemLineDetail': {
              'Qty': 1,
              'UnitPrice': 5000,
              'TaxCodeRef': {'value': 'VAT12'},
              'AtcCode': 'WC160',
            },
          },
        ],
      });
      expect(qboBill.direction, 'PURCHASE');
      expect(qboBill.status, 'TRANSMITTED');

      final odooInv = await engine.ingestFromOdoo({
        'id': 42,
        'name': 'ODOO/2026/01',
        'move_type': 'out_invoice',
        'partner_id': {'name': 'Odoo Buyer Inc', 'vat': '005444555'},
        'invoice_line_ids': [
          {
            'name': 'ERP Implementation',
            'quantity': 1,
            'price_unit': 20000,
            'tax_ids': ['VAT_12'],
          },
        ],
      });
      expect(odooInv.status, 'TRANSMITTED');

      final csvBatch = await engine.ingestFromCsvBatch(
        [
          'CompInvoiceId,BuyerName,BuyerTin,DocType,TransClass,ItemNm,Qty,UnitPrice,TaxClassification,AtcCode',
          'CSV-001,Batch Client One,004111222,01,B2B,Printer Ink,3,1000,VATABLE,',
        ].join('\n'),
      );
      expect(csvBatch.length, 1);
      expect(csvBatch.first.status, 'TRANSMITTED');

      final cm = await engine.issueCreditMemo(
        odooInv.id,
        reason: 'Service adjustment',
      );
      expect(cm.payload.docType, '03');
      expect(cm.payload.corrYN, 'Y');
      expect(cm.payload.refEisUniqueId, odooInv.payload.eisUniqueId);

      final books = engine.getCasBooks();
      final tb = books['trialBalance'] as Map<String, dynamic>;
      expect(tb['isBalanced'], isTrue);
      expect((tb['totalDebits'] as num) > 0, isTrue);
      expect(tb['totalDebits'], tb['totalCredits']);

      final entries = books['entries'] as List<dynamic>;
      expect(entries.any((e) => (e as Map)['bookType'] == 'SJ'), isTrue);
      expect(entries.any((e) => (e as Map)['bookType'] == 'PJ'), isTrue);
      expect(entries.any((e) => (e as Map)['bookType'] == 'GJ'), isTrue);

      final slspSales = engine.generateSlsp(null, 'SALES', period: '202611');
      expect(slspSales['datContent'].toString(), contains('H,S,'));
      expect(slspSales['datContent'].toString(), contains('D,S,'));

      final sawt =
          engine.generateWithholdingDat(null, 'SAWT', period: '202612');
      expect(sawt['datContent'].toString(), contains('HSAWT,H1702Q'));
      expect(sawt['rowCount'], 1);

      final qap = engine.generateWithholdingDat(null, 'QAP', period: '202612');
      expect(qap['datContent'].toString(), contains('HQAP,H1601EQ'));
      expect(qap['rowCount'], 1);

      final f2307 = engine.generateForm2307ForInvoice(xeroInv.id);
      expect(f2307['totalTaxWithheld'], 200);
      expect(f2307['printableHtml'].toString(), contains('BIR Form No. 2307'));

      final audit = engine.auditTrail.verifyIntegrity();
      expect(audit['valid'], isTrue);
      expect((audit['totalEntries'] as num) >= 8, isTrue);
    });

    test(
        'persists taxpayers, sequence counters, invoices, CAS books, and Annex B audit trail to JSON and reloads cleanly',
        () async {
      // final tempDir = Directory.systemTemp.createTempSync('eis_v2_store_test_');
      // Gene - Nov, 20, 2026: Renamed temp test prefix from eis_v2_store_test_ to eis_store_test_.
      final tempDir = Directory.systemTemp.createTempSync('eis_store_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final storePath = '${tempDir.path}${Platform.pathSeparator}eis_store.json';

      final engine1 = EisEngineService(persistPath: storePath);
      await engine1.seedDefaultDemoDataIfEmpty();
      expect(engine1.getInvoices().length, 5);
      final firstTp = engine1.getTaxpayerById();
      expect(firstTp.lastEisSequence, 5);

      // Reload from disk in a fresh EisEngineService instance.
      final engine2 = EisEngineService(persistPath: storePath);
      await engine2.seedDefaultDemoDataIfEmpty();

      expect(engine2.getTaxpayers().length, 1);
      final reloadedTp = engine2.getTaxpayerById();
      expect(reloadedTp.keyId, firstTp.keyId);
      expect(reloadedTp.lastEisSequence, 5);
      expect(engine2.getInvoices().length, 5);

      // Verify previously transmitted EisUniqueIds remain protected against DUP001 after reload.
      final existingInv = engine2.getInvoices().first;
      final dupReceipt = await engine2.gateway.transmitEnvelope(
        existingInv.aesEnvelope,
        reloadedTp,
      );
      expect(dupReceipt.ackCode, 'DUP001');

      // Verify CAS Trial Balance and Annex B SHA-256 chain integrity survive reload.
      final books = engine2.getCasBooks();
      final tb = books['trialBalance'] as Map<String, dynamic>;
      expect(tb['isBalanced'], isTrue);

      final audit = engine2.auditTrail.verifyIntegrity();
      expect(audit['valid'], isTrue);
      expect(audit['totalEntries'], engine1.auditTrail.getEntries().length);

      // New invoice after reload continues monotonic sequence (#6).
      final nextInv = await engine2.ingestAndTransmitInvoice(
        const CanonicalIngestInput(
          sourceSystem: 'IES_UI',
          transClass: 'B2C',
          buyerName: 'Reload Walk-in',
          items: [
            RawLineItemInput(itemNm: 'Reload Item', qty: 1, unitPrice: 1000),
          ],
        ),
      );
      expect(nextInv.status, 'TRANSMITTED');
      expect(nextInv.payload.eisUniqueId, endsWith('00000006'));
    });
  });
}
