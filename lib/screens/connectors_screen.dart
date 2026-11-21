// Gene - Nov, 20, 2026: Ported from eis_flutter screens.
// Gene - Nov, 20, 2026: Upgraded ERP Connectors with Soft UI 2.0 responsive grid, sculpted notification card, icon badges, and recessed endpoint pills.
import 'package:material_ui/material_ui.dart';
import '../models/ies_models.dart';
import '../services/ies_api_client.dart';
import '../theme/eis_neumorphic_theme.dart';
import '../widgets/neumorphic_widgets.dart';
import '../widgets/shared_components.dart';

class ConnectorsScreen extends StatefulWidget {
  final TaxpayerProfileModel? activeTaxpayer;
  final IesApiClient api;
  final VoidCallback onSynced;

  const ConnectorsScreen({
    super.key,
    required this.activeTaxpayer,
    required this.api,
    required this.onSynced,
  });

  @override
  State<ConnectorsScreen> createState() => _ConnectorsScreenState();
}

class _ConnectorsScreenState extends State<ConnectorsScreen> {
  final _csvCtrl = TextEditingController(
    text: 'CompInvoiceId,BuyerName,BuyerTin,DocType,TransClass,ItemNm,Qty,UnitPrice,TaxClassification,AtcCode\n'
        'CSV-2026-001,Salamat Logistics Corp,007123987,01,B2B,Thermal Printer Rolls,10,450,VATABLE,WC158\n'
        'CSV-2026-002,Visayas Tech Hub Inc,006987321,02,B2B,Cloud Compliance Audit,1,35000,VATABLE,WC160',
  );
  bool _busy = false;
  String? _statusMessage;

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSampleSync(String connector) async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final tpId = widget.activeTaxpayer?.id;
      final suffix = DateTime.now().millisecondsSinceEpoch % 10000;
      late final StoredInvoiceModel rec;

      if (connector == 'xero') {
        rec = await widget.api.syncConnector(
          'xero',
          {
            'InvoiceID': 'xero-sync-$suffix',
            'InvoiceNumber': 'XERO-SYNC-$suffix',
            'Type': 'ACCREC',
            'Status': 'AUTHORISED',
            'Contact': {
              'Name': 'Luzon Manufacturing Corp (via Xero)',
              'TaxNumber': '008765432',
            },
            'LineItems': [
              {
                'ItemCode': 'XERO-SVC',
                'Description': 'Monthly ERP Accounting Bridge',
                'Quantity': 1,
                'UnitAmount': 42000,
                'TaxType': 'OUTPUT',
                'AtcCode': 'WC160',
              },
            ],
          },
          taxpayerId: tpId,
        );
      } else if (connector == 'quickbooks') {
        rec = await widget.api.syncConnector(
          'quickbooks',
          {
            'Id': 'qbo-sync-$suffix',
            'DocNumber': 'QBO-INV-$suffix',
            'TxnType': 'Invoice',
            'CustomerRef': {
              'name': 'Mindanao Agri Exports Inc (via QBO)',
              'tin': '005889900',
              'branchCd': '0000',
            },
            'Line': [
              {
                'Description': 'Agri-Supply Export Automation',
                'SalesItemLineDetail': {
                  'Qty': 2,
                  'UnitPrice': 18500,
                  'TaxCodeRef': {'value': 'VAT12'},
                  'AtcCode': 'WC160',
                },
              },
            ],
          },
          taxpayerId: tpId,
        );
      } else {
        rec = await widget.api.syncConnector(
          'odoo',
          {
            'id': suffix,
            'name': 'ODOO/2026/$suffix',
            'move_type': 'out_invoice',
            'partner_id': {
              'name': 'Davao Retail Group Corp (via Odoo)',
              'vat': '004667788',
              'city': 'Davao City',
            },
            'invoice_line_ids': [
              {
                'product_code': 'ODOO-POS',
                'name': 'Odoo l10n_ph POS Integration Pack',
                'quantity': 3,
                'price_unit': 12000,
                'tax_ids': ['VAT_12'],
                'l10n_ph_atc': 'WC160',
              },
            ],
          },
          taxpayerId: tpId,
        );
      }

      setState(() {
        _statusMessage =
            'Synced ${rec.compInvoiceId} from ${connector.toUpperCase()} -> ${rec.ackCode} (${rec.eisUniqueId})';
      });
      widget.onSynced();
    } catch (e) {
      setState(() => _statusMessage = 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importCsv() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final count = await widget.api.importCsvBatch(
        _csvCtrl.text,
        taxpayerId: widget.activeTaxpayer?.id,
      );
      setState(() {
        _statusMessage = 'CSV Batch imported & transmitted $count invoice(s) to BIR EIS.';
      });
      widget.onSynced();
    } catch (e) {
      setState(() => _statusMessage = 'CSV Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       padding: const EdgeInsets.all(20),
//       children: [
//         if (_statusMessage != null)
//           Padding(
//             padding: const EdgeInsets.only(bottom: 14),
//             child: MaterialBanner(
//               content: Text(_statusMessage!),
//               leading: const Icon(Icons.check_circle_outline_rounded),
//               actions: [
//                 TextButton(
//                   onPressed: () => setState(() => _statusMessage = null),
//                   child: const Text('Dismiss'),
//                 ),
//               ],
//             ),
//           ),
//         Wrap(
//           spacing: 12,
//           runSpacing: 12,
//           children: [
//             _connectorCard(
//               context,
//               title: 'Xero Accounting (OAuth2 / Webhook)',
//               subtitle:
//                   'Maps ACCREC/ACCPAY & TaxTypes (OUTPUT, EXEMPTOUTPUT, ZERORATEDOUTPUT) into BIR v2.01 + CAS Books.',
//               icon: Icons.sync_alt_rounded,
//               endpoint: 'POST /api/connectors/xero',
//               onTest: () => _runSampleSync('xero'),
//             ),
//             _connectorCard(
//               context,
//               title: 'QuickBooks Online (QBO)',
//               subtitle:
//                   'Maps QBO Invoice, CreditMemo & Bill payloads with Line TaxCodeRef & Customer TIN into BIR EIS + QAP/2307.',
//               icon: Icons.cloud_sync_rounded,
//               endpoint: 'POST /api/connectors/quickbooks',
//               onTest: () => _runSampleSync('quickbooks'),
//             ),
//             _connectorCard(
//               context,
//               title: 'Odoo ERP (l10n_ph account.move)',
//               subtitle:
//                   'Maps Odoo out_invoice / out_refund / in_invoice + l10n_ph_atc withholding lines directly to BIR EIS & CAS.',
//               icon: Icons.hub_rounded,
//               endpoint: 'POST /api/connectors/odoo',
//               onTest: () => _runSampleSync('odoo'),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         SectionCard(
//           title: 'CSV / Excel Batch Importer (Up to 100 Invoices / Batch)',
//           subtitle:
//               'Paste CSV lines to validate EOPT tax rules, generate 24-char EisUniqueIds, JWS-sign, AES-encrypt, and transmit.',
//           trailing: FilledButton.icon(
//             onPressed: _busy ? null : _importCsv,
//             icon: const Icon(Icons.upload_file_rounded),
//             label: const Text('Import & Transmit Batch'),
//           ),
//           child: TextField(
//             controller: _csvCtrl,
//             maxLines: 6,
//             style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
//             decoration: const InputDecoration(
//               border: OutlineInputBorder(),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _connectorCard(
//     BuildContext context, {
//     required String title,
//     required String subtitle,
//     required IconData icon,
//     required String endpoint,
//     required VoidCallback onTest,
//   }) {
//     return SizedBox(
//       width: 380,
//       child: SectionCard(
//         title: title,
//         subtitle: endpoint,
//         trailing: Icon(icon, color: Theme.of(context).colorScheme.primary),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
//             const SizedBox(height: 12),
//             FilledButton.tonalIcon(
//               onPressed: _busy ? null : onTest,
//               icon: const Icon(Icons.play_arrow_rounded),
//               label: const Text('Test Live Sync to BIR EIS'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
  // Gene - Nov, 20, 2026: Responsive 3/2/1 connector card layout, neumorphic notification card, and endpoint pills.
  @override
  Widget build(BuildContext context) {
    final tokens = EisNeumorphicTokens.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_statusMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: NeumorphicSurface(
              depth: NeumorphicDepth.subtle,
              borderRadius: 16,
              tintColor: tokens.accentPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  NeumorphicIconBadge(
                    icon: Icons.check_circle_outline_rounded,
                    color: tokens.success,
                    size: 36,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _statusMessage = null),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 1050
                ? 3
                : constraints.maxWidth > 680
                    ? 2
                    : 1;
            final cardWidth = (constraints.maxWidth - (cols - 1) * 14) / cols;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _connectorCard(
                  context,
                  width: cardWidth,
                  title: 'Xero Accounting (OAuth2 / Webhook)',
                  subtitle:
                      'Maps ACCREC/ACCPAY & TaxTypes (OUTPUT, EXEMPTOUTPUT, ZERORATEDOUTPUT) into BIR v2.01 + CAS Books.',
                  icon: Icons.sync_alt_rounded,
                  endpoint: 'POST /api/connectors/xero',
                  onTest: () => _runSampleSync('xero'),
                ),
                _connectorCard(
                  context,
                  width: cardWidth,
                  title: 'QuickBooks Online (QBO)',
                  subtitle:
                      'Maps QBO Invoice, CreditMemo & Bill payloads with Line TaxCodeRef & Customer TIN into BIR EIS + QAP/2307.',
                  icon: Icons.cloud_sync_rounded,
                  endpoint: 'POST /api/connectors/quickbooks',
                  onTest: () => _runSampleSync('quickbooks'),
                ),
                _connectorCard(
                  context,
                  width: cardWidth,
                  title: 'Odoo ERP (l10n_ph account.move)',
                  subtitle:
                      'Maps Odoo out_invoice / out_refund / in_invoice + l10n_ph_atc withholding lines directly to BIR EIS & CAS.',
                  icon: Icons.hub_rounded,
                  endpoint: 'POST /api/connectors/odoo',
                  onTest: () => _runSampleSync('odoo'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        SectionCard(
          icon: Icons.upload_file_rounded,
          title: 'CSV / Excel Batch Importer (Up to 100 Invoices / Batch)',
          subtitle:
              'Paste CSV lines to validate EOPT tax rules, generate 24-char EisUniqueIds, JWS-sign, AES-encrypt, and transmit.',
          trailing: FilledButton.icon(
            onPressed: _busy ? null : _importCsv,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Import & Transmit Batch'),
          ),
          child: TextField(
            controller: _csvCtrl,
            maxLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _connectorCard(
    BuildContext context, {
    required double width,
    required String title,
    required String subtitle,
    required IconData icon,
    required String endpoint,
    required VoidCallback onTest,
  }) {
    final tokens = EisNeumorphicTokens.of(context);
    return SizedBox(
      width: width,
      child: NeumorphicSurface(
        depth: NeumorphicDepth.raised,
        borderRadius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NeumorphicIconBadge(
                  icon: icon,
                  color: tokens.accentPrimary,
                  size: 40,
                  iconSize: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NeumorphicWell(
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                endpoint,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.accentSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : onTest,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Test Live Sync to BIR EIS'),
            ),
          ],
        ),
      ),
    );
  }
}
