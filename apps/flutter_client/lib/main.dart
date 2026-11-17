import 'package:material_ui/material_ui.dart';
import 'models/ies_models.dart';
import 'screens/cas_books_screen.dart';
import 'screens/command_center_screen.dart';
import 'screens/connectors_screen.dart';
import 'screens/invoicing_pos_screen.dart';
import 'screens/statutory_reports_screen.dart';
import 'screens/vault_audit_screen.dart';
import 'services/ies_api_client.dart';

void main() {
  runApp(const IesApp());
}

class IesApp extends StatelessWidget {
  final IesApiClient? apiClient;

  const IesApp({super.key, this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IES — Philippine BIR EIS & CAS Compliance Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF14B8A6),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: IesHomeShell(api: apiClient ?? IesApiClient()),
    );
  }
}

class IesHomeShell extends StatefulWidget {
  final IesApiClient api;

  const IesHomeShell({super.key, required this.api});

  @override
  State<IesHomeShell> createState() => _IesHomeShellState();
}

class _IesHomeShellState extends State<IesHomeShell> {
  int _selectedIndex = 0;
  DashboardSummaryModel? _summary;
  List<TaxpayerProfileModel> _taxpayers = const [];
  TaxpayerProfileModel? _activeTaxpayer;
  List<StoredInvoiceModel> _invoices = const [];
  String? _error;
  bool _loading = true;

  static const _destinations = [
    (label: 'EIS Command', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
    (label: 'Invoicing / POS', icon: Icons.point_of_sale_outlined, activeIcon: Icons.point_of_sale),
    (label: 'ERP Connectors', icon: Icons.hub_outlined, activeIcon: Icons.hub),
    (label: 'CAS 6 Books', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book),
    (label: '.DAT & 2307', icon: Icons.file_download_outlined, activeIcon: Icons.file_download),
    (label: 'Vault & Audit', icon: Icons.verified_user_outlined, activeIcon: Icons.verified_user),
  ];

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final taxpayers = await widget.api.fetchTaxpayers();
      final selectedTp = _activeTaxpayer != null &&
              taxpayers.any((t) => t.id == _activeTaxpayer!.id)
          ? taxpayers.firstWhere((t) => t.id == _activeTaxpayer!.id)
          : (taxpayers.isNotEmpty ? taxpayers.first : null);

      final summary = await widget.api.fetchDashboard(taxpayerId: selectedTp?.id);
      final invoices = await widget.api.fetchInvoices(taxpayerId: selectedTp?.id);

      if (mounted) {
        setState(() {
          _taxpayers = taxpayers;
          _activeTaxpayer = selectedTp;
          _summary = summary;
          _invoices = invoices;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 820;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'IES • BIR EIS v2.01 & CAS Hub',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          if (_taxpayers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _activeTaxpayer?.id,
                  items: _taxpayers
                      .map((tp) => DropdownMenuItem(
                            value: tp.id,
                            child: Text('${tp.businessName} (TIN ${tp.tin})'),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() {
                      _activeTaxpayer =
                          _taxpayers.firstWhere((t) => t.id == id);
                    });
                    _refreshAll();
                  },
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh Backend Data',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1150,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              destinations: _destinations
                  .map((d) => NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.activeIcon),
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded,
                              size: 48,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            'Cannot connect to IES Backend (${widget.api.baseUrl})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _refreshAll,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry Connection'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _loading && _summary == null
                    ? const Center(child: CircularProgressIndicator())
                    : IndexedStack(
                        index: _selectedIndex,
                        children: [
                          CommandCenterScreen(
                            summary: _summary,
                            invoices: _invoices,
                            api: widget.api,
                            onRefresh: _refreshAll,
                          ),
                          InvoicingPosScreen(
                            activeTaxpayer: _activeTaxpayer,
                            api: widget.api,
                            onInvoiceCreated: _refreshAll,
                          ),
                          ConnectorsScreen(
                            activeTaxpayer: _activeTaxpayer,
                            api: widget.api,
                            onSynced: _refreshAll,
                          ),
                          CasBooksScreen(
                            activeTaxpayer: _activeTaxpayer,
                            api: widget.api,
                          ),
                          StatutoryReportsScreen(
                            activeTaxpayer: _activeTaxpayer,
                            invoices: _invoices,
                            api: widget.api,
                          ),
                          VaultAuditScreen(
                            taxpayers: _taxpayers,
                            api: widget.api,
                            onRefresh: _refreshAll,
                          ),
                        ],
                      ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              destinations: _destinations
                  .map((d) => NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.activeIcon),
                        label: d.label,
                      ))
                  .toList(),
            ),
    );
  }
}
