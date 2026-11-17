import 'package:material_ui/material_ui.dart';
import '../models/ies_models.dart';
import '../services/ies_api_client.dart';
import '../widgets/shared_components.dart';

class StatutoryReportsScreen extends StatefulWidget {
  final TaxpayerProfileModel? activeTaxpayer;
  final List<StoredInvoiceModel> invoices;
  final IesApiClient api;

  const StatutoryReportsScreen({
    super.key,
    required this.activeTaxpayer,
    required this.invoices,
    required this.api,
  });

  @override
  State<StatutoryReportsScreen> createState() => _StatutoryReportsScreenState();
}

class _StatutoryReportsScreenState extends State<StatutoryReportsScreen> {
  StatutoryReportModel? _activeReport;
  Map<String, dynamic>? _activeForm2307;
  String _activeTitle = '';
  bool _loading = false;

  Future<void> _loadReport(String type) async {
    setState(() {
      _loading = true;
      _activeForm2307 = null;
    });
    try {
      final tpId = widget.activeTaxpayer?.id;
      late final StatutoryReportModel rep;
      switch (type) {
        case 'SLSP_SALES':
          _activeTitle = 'BIR RELIEF — Summary List of Sales (SLSP .DAT / .CSV)';
          rep = await widget.api.fetchSlsp(taxpayerId: tpId, kind: 'SALES');
        case 'SLSP_PURCHASES':
          _activeTitle = 'BIR RELIEF — Summary List of Purchases (SLSP .DAT / .CSV)';
          rep = await widget.api.fetchSlsp(taxpayerId: tpId, kind: 'PURCHASES');
        case 'SAWT':
          _activeTitle = 'BIR SAWT — Summary Alphalist of Withholding Taxes (.DAT)';
          rep = await widget.api.fetchWithholdingDat(taxpayerId: tpId, kind: 'SAWT');
        default:
          _activeTitle = 'BIR QAP — Quarterly Alphalist of Payees 1601-EQ (.DAT)';
          rep = await widget.api.fetchWithholdingDat(taxpayerId: tpId, kind: 'QAP');
      }
      if (mounted) setState(() => _activeReport = rep);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load2307(String invoiceId) async {
    setState(() {
      _loading = true;
      _activeReport = null;
    });
    try {
      final data = await widget.api.fetchForm2307(invoiceId);
      if (mounted) {
        setState(() {
          _activeTitle = 'BIR Form No. 2307 — ${data['referenceInvoice']}';
          _activeForm2307 = data;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cwtInvoices = widget.invoices
        .where((i) => i.summary.withholdingTaxAmt > 0)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionCard(
          title: 'BIR Statutory .DAT / .CSV File Generators',
          subtitle:
              'Generate BIR RELIEF SLSP, SAWT, and QAP (1601-EQ) transmittal files compliant with BIR validation modules.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : () => _loadReport('SLSP_SALES'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('SLSP Sales (.DAT)'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _loadReport('SLSP_PURCHASES'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('SLSP Purchases (.DAT)'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _loadReport('SAWT'),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('SAWT Alphalist (.DAT)'),
              ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : () => _loadReport('QAP'),
                icon: const Icon(Icons.summarize_outlined),
                label: const Text('QAP 1601-EQ (.DAT)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'BIR Form 2307 Certificates (Creditable Tax Withheld at Source)',
          subtitle:
              'Invoices carrying ATC codes (${cwtInvoices.length} available)',
          child: cwtInvoices.isEmpty
              ? const Text('No invoices with CWT/ATC withholding recorded yet.')
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cwtInvoices.map((inv) {
                    return ActionChip(
                      avatar: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(
                        '${inv.compInvoiceId} (${formatPhp(inv.summary.withholdingTaxAmt)})',
                      ),
                      onPressed: () => _load2307(inv.id),
                    );
                  }).toList(),
                ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_activeReport != null) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: _activeTitle,
            subtitle:
                'Filename: ${_activeReport!.filename}  |  Rows: ${_activeReport!.rowCount}',
            child: DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'BIR .DAT Format'),
                      Tab(text: 'CSV Export'),
                    ],
                  ),
                  SizedBox(
                    height: 260,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            _activeReport!.datContent,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            _activeReport!.csvContent,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_activeForm2307 != null) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: _activeTitle,
            subtitle:
                'Period: ${_activeForm2307!['periodFrom']} to ${_activeForm2307!['periodTo']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payee: ${(_activeForm2307!['payee'] as Map)['name']} (TIN: ${(_activeForm2307!['payee'] as Map)['tin']})',
                ),
                Text(
                  'Payor: ${(_activeForm2307!['payor'] as Map)['name']} (TIN: ${(_activeForm2307!['payor'] as Map)['tin']})',
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Tax Withheld: ${formatPhp((_activeForm2307!['totalTaxWithheld'] as num).toDouble())}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text('Printable HTML Template:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _activeForm2307!['printableHtml'].toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
