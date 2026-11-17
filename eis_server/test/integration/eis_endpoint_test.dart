import 'dart:convert';
import 'package:eis_server/src/bir/bir_eis_schema.dart';
import 'package:eis_server/src/bir/eis_engine_service.dart';
import 'package:eis_server/src/bir/eis_runtime.dart';
import 'package:test/test.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given EisEndpoint', (sessionBuilder, endpoints) {
    setUp(() async {
      final engine = EisEngineService(persistPath: null);
      engine.registerTaxpayer(
        tin: '009123456',
        taxType: 'VAT',
        registeredName: 'Mabuhay Tech & Solutions Inc.',
        businessName: 'Mabuhay Tech PH',
        email: 'compliance@mabuhaytech.ph',
        eisCertId: 'EISC2026',
        headOfficeAddress: const BirAddress(
          street: '24F Ayala Tower One',
          barangay: 'Bel-Air',
          city: 'Makati City',
          province: 'Metro Manila',
          zipCode: '1226',
        ),
      );
      EisRuntime.setEngineForTesting(engine);
    });

    test('creates and transmits BIR EIS v2.01 invoice via Serverpod RPC endpoint', () async {
      final createdRaw = await endpoints.eis.createInvoice(
        sessionBuilder,
        jsonEncode({
          'sourceSystem': 'IES_UI',
          'transClass': 'B2B',
          'buyerName': 'Serverpod RPC Client Corp.',
          'buyerTin': '008555666',
          'items': [
            {
              'itemNm': 'BIR CAS Compliance Retainer',
              'qty': 1,
              'unitPrice': 50000,
              'taxClassification': 'VATABLE',
              'atcCode': 'WC160',
            },
          ],
        }),
      );
      final created = jsonDecode(createdRaw) as Map<String, dynamic>;
      expect(created['status'], 'TRANSMITTED');
      expect((created['lastReceipt'] as Map)['ackCode'], 'ACK-200');

      final summaryRaw = await endpoints.eis.getDashboardSummary(sessionBuilder);
      final summary = jsonDecode(summaryRaw) as Map<String, dynamic>;
      expect((summary['invoiceCounts'] as Map)['transmitted'], 1);
      expect((summary['auditChain'] as Map)['valid'], isTrue);
    });
  });
}
