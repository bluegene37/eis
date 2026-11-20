// Gene - Nov, 20, 2026: Ported BIR EIS/CAS widget & calculator tests from eis_flutter and added full embedded-engine UI integration test.
import 'dart:convert';
import 'package:eis_v2/core/bir/eis_engine_service.dart';
import 'package:eis_v2/main.dart';
import 'package:eis_v2/models/ies_models.dart';
import 'package:eis_v2/services/ies_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

IesApiClient buildMockApiClient() {
  final mockHttp = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/taxpayers')) {
      return http.Response(
        jsonEncode([
          {
            'id': 'TP-001',
            'workspaceId': 'WS-PH-DEFAULT',
            'tin': '009123456',
            'taxType': 'VAT',
            'registeredName': 'Mabuhay Tech & Solutions Inc.',
            'businessName': 'Mabuhay Tech PH',
            'email': 'compliance@mabuhaytech.ph',
            'eisCertId': 'EISC2026',
            'pttNumber': 'PTT-2026-0881',
            'keyId': 'bir-009123456-eisc2026',
            'publicKeyPem': '---PUBLIC KEY---',
            'branches': [
              {
                'branchCd': '0000',
                'branchName': 'Head Office',
                'address': {
                  'Street': 'Ayala Ave',
                  'Barangay': 'Bel-Air',
                  'City': 'Makati City',
                  'Province': 'Metro Manila',
                  'ZipCode': '1226',
                },
                'lastSequence': 5,
                'invoicePrefix': 'SI-0000',
              },
            ],
          },
        ]),
        200,
      );
    }
    if (path.endsWith('/dashboard/summary')) {
      return http.Response(
        jsonEncode({
          'gatewayConfig': {'mode': 'MOCK_BIR_SIMULATOR', 'simulateOutage': false},
          'taxpayerCount': 1,
          'invoiceCounts': {
            'total': 5,
            'transmitted': 5,
            'queuedRetry': 0,
            'rejected': 0,
          },
          'financialsPhp': {
            'totalSales': 250000,
            'totalOutputVat': 27000,
            'totalCwt': 3500,
          },
          'bySource': {'IES_UI': 2, 'XERO': 1, 'QUICKBOOKS': 1, 'ODOO': 1},
          'auditChain': {'valid': true, 'totalEntries': 6},
        }),
        200,
      );
    }
    if (path.endsWith('/invoices')) {
      return http.Response(
        jsonEncode([
          {
            'id': 'INV-1',
            'taxpayerId': 'TP-001',
            'branchCd': '0000',
            'sourceSystem': 'XERO',
            'direction': 'SALES',
            'status': 'TRANSMITTED',
            'retryCount': 0,
            'threeDayDeadlineAt': '2026-11-20T00:00:00Z',
            'jwsToken': 'eyJhbGciOiJSUzI1NiJ9.payload.sig',
            'aesEnvelope': {'algorithm': 'AES-256-GCM'},
            'lastReceipt': {'ackCode': 'ACK-200', 'birAckId': 'BIR-ACK-001'},
            'payload': {
              'EisUniqueId': '20261117EISC202600000001',
              'CompInvoiceId': 'XERO-2026-104',
              'IssueDtm': '2026-11-17T12:00:00',
              'DocType': '01',
              'TransClass': 'B2B',
              'Buyer': {'RegNm': 'Bayanihan Retail Corp', 'TIN': '008445566'},
              'Summary': {
                'GrossSalesAmt': 100000,
                'TotalDiscountAmt': 0,
                'ScPwdDiscountAmt': 0,
                'NetSales': 100000,
                'VATableSales': 100000,
                'VATExemptSales': 0,
                'ZeroRatedSales': 0,
                'VATAmt': 12000,
                'WithholdingTaxAmt': 2000,
                'TotalAmountDue': 110000,
              },
            },
          },
        ]),
        200,
      );
    }
    if (path.endsWith('/cas/books')) {
      return http.Response(
        jsonEncode({
          'entries': [],
          'trialBalance': {
            'rows': [],
            'totalDebits': 112000,
            'totalCredits': 112000,
            'isBalanced': true,
          },
        }),
        200,
      );
    }
    if (path.endsWith('/audit-trail')) {
      return http.Response(
        jsonEncode({
          'verification': {'valid': true, 'totalEntries': 1, 'brokenAtSeq': null},
          'entries': [
            {
              'seq': 1,
              'id': 'AUD-000001',
              'timestamp': '2026-11-17T12:00:00Z',
              'actor': 'system.admin',
              'action': 'REGISTER_TAXPAYER_TIN',
              'taxpayerTin': '009123456',
              'entityId': 'TP-001',
              'details': 'Registered taxpayer',
              'prevHash': 'GENESIS-BIR-ANNEX-B',
              'entryHash':
                  'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
            },
          ],
        }),
        200,
      );
    }
    return http.Response('{}', 200);
  });

  return IesApiClient(client: mockHttp);
}

void main() {
  test(
      'EoptPreviewCalculator computes 12% VAT, SC 20% VAT-Exempt, and CWT accurately',
      () {
    final b2b = EoptPreviewCalculator.compute(
      qty: 1,
      unitPrice: 100000,
      priceIncludesVat: false,
      taxClassification: 'VATABLE',
      buyerCategory: 'REGULAR',
      atcCode: 'WC160',
    );
    expect(b2b['vat'], closeTo(12000, 0.01));
    expect(b2b['cwt'], closeTo(2000, 0.01));
    expect(b2b['totalDue'], closeTo(110000, 0.01));

    final sc = EoptPreviewCalculator.compute(
      qty: 1,
      unitPrice: 1120,
      priceIncludesVat: true,
      taxClassification: 'VATABLE',
      buyerCategory: 'SENIOR_CITIZEN',
      atcCode: null,
    );
    expect(sc['gross'], closeTo(1000, 0.01));
    expect(sc['discount'], closeTo(200, 0.01));
    expect(sc['vat'], closeTo(0, 0.01));
    expect(sc['totalDue'], closeTo(800, 0.01));
  });

  testWidgets(
      'IES App renders Command Center and switches across BIR compliance tabs (REST mock)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(IesApp(apiClient: buildMockApiClient()));
    await tester.pumpAndSettle();

    expect(find.text('IES • BIR EIS v2.01 & CAS Hub'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('XERO-2026-104'), findsOneWidget);

    await tester.tap(find.text('CAS 6 Books'));
    await tester.pumpAndSettle();
    expect(find.text('BALANCED (DR == CR)'), findsOneWidget);

    await tester.tap(find.text('Vault & Audit'));
    await tester.pumpAndSettle();
    expect(find.text('CHAIN VERIFIED (1)'), findsOneWidget);
  });

  testWidgets(
      'IES App runs standalone with embedded BIR EIS/CAS engine and transmits live invoices',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final engine = EisEngineService(persistPath: null);
    await engine.seedDefaultDemoDataIfEmpty();

    await tester.pumpWidget(
      IesApp(
        apiClient: IesApiClient(engineProvider: () async => engine),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Engine'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('XERO-2026-104'), findsOneWidget);

    await tester.tap(find.text('CAS 6 Books'));
    await tester.pumpAndSettle();
    expect(find.text('BALANCED (DR == CR)'), findsOneWidget);

    await tester.tap(find.text('Vault & Audit'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('CHAIN VERIFIED'),
      findsOneWidget,
    );

    // Issue a live invoice through the embedded engine and confirm KPI counter increments to 6 / 6.
    await tester.tap(find.text('Invoicing / POS'));
    await tester.pumpAndSettle();

    final submitBtn =
        find.text('Sign JWS, Encrypt AES-256 & Transmit to BIR EIS');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    await tester.tap(find.text('EIS Command'));
    await tester.pumpAndSettle();
    expect(find.text('6 / 6'), findsOneWidget);
  });
}

/*
// Original Flutter starter smoke test preserved per Code Modification & Deprecation Policy:
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:eis_v2/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
*/
