// Gene - Nov, 20, 2026: Standalone Philippine BIR EIS v2.01 & CAS Flutter application with embedded pure-Dart compliance engine and optional Remote REST API mode.
// Gene - Nov, 20, 2026: Added 3-mode backend support (Local Embedded Engine, Serverpod RPC :8080, and Remote REST API :4000).
import 'package:eis_client/eis_client.dart' as sp;
import 'package:material_ui/material_ui.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'models/ies_models.dart';
import 'screens/cas_books_screen.dart';
import 'screens/command_center_screen.dart';
import 'screens/connectors_screen.dart';
import 'screens/invoicing_pos_screen.dart';
import 'screens/statutory_reports_screen.dart';
import 'screens/vault_audit_screen.dart';
import 'services/ies_api_client.dart';

const _envRestUrl = String.fromEnvironment('EIS_REST_URL');
const _envServerpodUrl = String.fromEnvironment('EIS_SERVERPOD_URL');

// Gene - Nov, 20, 2026: Build a Serverpod RPC IesApiClient with Android Emulator localhost mapping and trailing slash normalization.
IesApiClient buildServerpodApiClient(String rawUrl) {
  final trimmed = rawUrl.trim().isEmpty ? 'http://localhost:8080' : rawUrl.trim();
  final resolved = trimmed.replaceFirst('://localhost', '://$localhost');
  final normalized = resolved.endsWith('/') ? resolved : '$resolved/';
  final client = sp.Client(normalized)
    ..connectivityMonitor = FlutterConnectivityMonitor();
  return IesApiClient(baseUrl: normalized, serverpodClient: client);
}

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   final initialClient = _envRestUrl.isNotEmpty
//       ? IesApiClient(baseUrl: _envRestUrl, useRemoteRest: true)
//       : IesApiClient();
//
//   runApp(IesApp(apiClient: initialClient));
// }
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final IesApiClient initialClient;
  if (_envServerpodUrl.isNotEmpty) {
    initialClient = buildServerpodApiClient(_envServerpodUrl);
  } else if (_envRestUrl.isNotEmpty) {
    initialClient = IesApiClient(baseUrl: _envRestUrl, useRemoteRest: true);
  } else {
    initialClient = IesApiClient();
  }

  runApp(IesApp(apiClient: initialClient));
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
  late IesApiClient _api;
  int _selectedIndex = 0;
  int _refreshNonce = 0;
  DashboardSummaryModel? _summary;
  List<TaxpayerProfileModel> _taxpayers = const [];
  TaxpayerProfileModel? _activeTaxpayer;
  List<StoredInvoiceModel> _invoices = const [];
  String? _error;
  bool _loading = true;

  static const _destinations = [
    (
      label: 'EIS Command',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
    ),
    (
      label: 'Invoicing / POS',
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale,
    ),
    (
      label: 'ERP Connectors',
      icon: Icons.hub_outlined,
      activeIcon: Icons.hub,
    ),
    (
      label: 'CAS 6 Books',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
    ),
    (
      label: '.DAT & 2307',
      icon: Icons.file_download_outlined,
      activeIcon: Icons.file_download,
    ),
    (
      label: 'Vault & Audit',
      icon: Icons.verified_user_outlined,
      activeIcon: Icons.verified_user,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _api = widget.api;
    _refreshAll();
  }

  @override
  void didUpdateWidget(covariant IesHomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      _api = widget.api;
      _activeTaxpayer = null;
      _refreshAll();
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final taxpayers = await _api.fetchTaxpayers();
      final selectedTp = _activeTaxpayer != null &&
              taxpayers.any((t) => t.id == _activeTaxpayer!.id)
          ? taxpayers.firstWhere((t) => t.id == _activeTaxpayer!.id)
          : (taxpayers.isNotEmpty ? taxpayers.first : null);

      final summary = await _api.fetchDashboard(taxpayerId: selectedTp?.id);
      final invoices = await _api.fetchInvoices(taxpayerId: selectedTp?.id);

      if (mounted) {
        setState(() {
          _taxpayers = taxpayers;
          _activeTaxpayer = selectedTp;
          _summary = summary;
          _invoices = invoices;
          _refreshNonce += 1;
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

  Future<void> _openBackendModeDialog() async {
    final nextClient = await showDialog<IesApiClient>(
      context: context,
      builder: (_) => _BackendModeDialog(currentClient: _api),
    );
    if (nextClient != null && mounted) {
      setState(() {
        _api = nextClient;
        _activeTaxpayer = null;
        _summary = null;
      });
      await _refreshAll();
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
            Icon(
              Icons.account_balance_wallet_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            // child: ActionChip(
            //   avatar: Icon(
            //     _api.isEmbedded ? Icons.memory_rounded : Icons.cloud_outlined,
            //     size: 16,
            //   ),
            //   label: Text(
            //     _api.isEmbedded ? 'Local Engine' : 'REST API',
            //     style: const TextStyle(fontSize: 12),
            //   ),
            //   tooltip: 'Backend Mode (${_api.connectionLabel})',
            //   onPressed: _openBackendModeDialog,
            // ),
            // Gene - Nov, 20, 2026: Display 3-mode icon and label (Local Engine / Serverpod RPC / REST API).
            child: ActionChip(
              avatar: Icon(
                switch (_api.backendMode) {
                  EisBackendMode.embedded => Icons.memory_rounded,
                  EisBackendMode.serverpod => Icons.dns_rounded,
                  EisBackendMode.remoteRest => Icons.cloud_outlined,
                },
                size: 16,
              ),
              label: Text(
                _api.modeChipLabel,
                style: const TextStyle(fontSize: 12),
              ),
              tooltip: 'Backend Mode (${_api.connectionLabel})',
              onPressed: _openBackendModeDialog,
            ),
          ),
          if (_taxpayers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _activeTaxpayer?.id,
                  items: _taxpayers
                      .map(
                        (tp) => DropdownMenuItem(
                          value: tp.id,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              '${tp.businessName} (TIN ${tp.tin})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
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
            tooltip: 'Refresh Data',
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
              onDestinationSelected: (idx) =>
                  setState(() => _selectedIndex = idx),
              destinations: _destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.activeIcon),
                      label: Text(d.label),
                    ),
                  )
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
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Cannot load IES Data (${_api.connectionLabel})',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: _refreshAll,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openBackendModeDialog,
                                icon: const Icon(Icons.tune_rounded),
                                label: const Text('Backend Mode'),
                              ),
                            ],
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
                            api: _api,
                            onRefresh: _refreshAll,
                          ),
                          InvoicingPosScreen(
                            activeTaxpayer: _activeTaxpayer,
                            api: _api,
                            onInvoiceCreated: _refreshAll,
                          ),
                          ConnectorsScreen(
                            activeTaxpayer: _activeTaxpayer,
                            api: _api,
                            onSynced: _refreshAll,
                          ),
                          CasBooksScreen(
                            activeTaxpayer: _activeTaxpayer,
                            api: _api,
                            refreshNonce: _refreshNonce,
                          ),
                          StatutoryReportsScreen(
                            activeTaxpayer: _activeTaxpayer,
                            invoices: _invoices,
                            api: _api,
                          ),
                          VaultAuditScreen(
                            taxpayers: _taxpayers,
                            api: _api,
                            onRefresh: _refreshAll,
                            refreshNonce: _refreshNonce,
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
              onDestinationSelected: (idx) =>
                  setState(() => _selectedIndex = idx),
              destinations: _destinations
                  .map(
                    (d) => NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.activeIcon),
                      label: d.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _BackendModeDialog extends StatefulWidget {
  final IesApiClient currentClient;

  const _BackendModeDialog({required this.currentClient});

  @override
  State<_BackendModeDialog> createState() => _BackendModeDialogState();
}

// class _BackendModeDialogState extends State<_BackendModeDialog> {
//   late bool _useRemoteRest;
//   late final TextEditingController _urlCtrl;
//
//   @override
//   void initState() {
//     super.initState();
//     _useRemoteRest = widget.currentClient.useRemoteRest;
//     _urlCtrl = TextEditingController(
//       text: widget.currentClient.baseUrl.isNotEmpty
//           ? widget.currentClient.baseUrl
//           : 'http://localhost:4000',
//     );
//   }
//
//   @override
//   void dispose() {
//     _urlCtrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Backend Execution Mode'),
//       content: SizedBox(
//         width: 440,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             SegmentedButton<bool>(
//               segments: const [
//                 ButtonSegment(
//                   value: false,
//                   label: Text('Embedded Local Engine'),
//                   icon: Icon(Icons.memory_rounded),
//                 ),
//                 ButtonSegment(
//                   value: true,
//                   label: Text('Remote REST API'),
//                   icon: Icon(Icons.cloud_outlined),
//                 ),
//               ],
//               selected: {_useRemoteRest},
//               onSelectionChanged: (sel) {
//                 setState(() => _useRemoteRest = sel.first);
//               },
//             ),
//             const SizedBox(height: 14),
//             if (!_useRemoteRest)
//               Text(
//                 'Runs the full pure-Dart BIR EIS v2.01 (RSA-2048 JWS, AES-256-GCM, EOPT, 6 CAS Books, .DAT/2307 & Annex B Hash Chain) directly inside this Flutter app.',
//                 style: Theme.of(context).textTheme.bodySmall,
//               )
//             else ...[
//               TextField(
//                 controller: _urlCtrl,
//                 decoration: const InputDecoration(
//                   labelText: 'REST Bridge Base URL',
//                   hintText: 'http://localhost:4000',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Tip: On Android Emulator use http://10.0.2.2:4000 to reach a local eis_server REST bridge.',
//                 style: Theme.of(context).textTheme.bodySmall,
//               ),
//             ],
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(),
//           child: const Text('Cancel'),
//         ),
//         FilledButton(
//           onPressed: () {
//             final url = _urlCtrl.text.trim().isEmpty
//                 ? 'http://localhost:4000'
//                 : _urlCtrl.text.trim();
//             Navigator.of(context).pop(
//               IesApiClient(baseUrl: url, useRemoteRest: _useRemoteRest),
//             );
//           },
//           child: const Text('Apply'),
//         ),
//       ],
//     );
//   }
// }
// Gene - Nov, 20, 2026: 3-mode backend switcher dialog supporting Local Embedded Engine, Serverpod RPC (:8080), and Remote REST (:4000).
class _BackendModeDialogState extends State<_BackendModeDialog> {
  late EisBackendMode _mode;
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _mode = widget.currentClient.backendMode;
    final currentUrl = widget.currentClient.baseUrl.trim();
    _urlCtrl = TextEditingController(
      text: currentUrl.isNotEmpty
          ? currentUrl
          : (_mode == EisBackendMode.serverpod
              ? 'http://localhost:8080/'
              : 'http://localhost:4000'),
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _onModeChanged(EisBackendMode nextMode) {
    setState(() {
      _mode = nextMode;
      final current = _urlCtrl.text.trim();
      if (nextMode == EisBackendMode.serverpod &&
          (current.isEmpty || current.contains(':4000'))) {
        _urlCtrl.text = 'http://localhost:8080/';
      } else if (nextMode == EisBackendMode.remoteRest &&
          (current.isEmpty || current.contains(':8080'))) {
        _urlCtrl.text = 'http://localhost:4000';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Backend Execution Mode'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<EisBackendMode>(
              segments: const [
                ButtonSegment(
                  value: EisBackendMode.embedded,
                  label: Text('Local'),
                  icon: Icon(Icons.memory_rounded),
                ),
                ButtonSegment(
                  value: EisBackendMode.serverpod,
                  label: Text('Serverpod'),
                  icon: Icon(Icons.dns_rounded),
                ),
                ButtonSegment(
                  value: EisBackendMode.remoteRest,
                  label: Text('REST'),
                  icon: Icon(Icons.cloud_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (sel) => _onModeChanged(sel.first),
            ),
            const SizedBox(height: 14),
            if (_mode == EisBackendMode.embedded)
              Text(
                'Runs the full pure-Dart BIR EIS v2.01 (RSA-2048 JWS, AES-256-GCM, EOPT, 6 CAS Books, .DAT/2307 & Annex B Hash Chain) directly inside this Flutter app.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (_mode == EisBackendMode.serverpod) ...[
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Serverpod RPC URL',
                  hintText: 'http://localhost:8080/',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start backend: cd server/eis_server && dart bin/main.dart (localhost auto-maps to 10.0.2.2 on Android Emulator).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'REST Bridge Base URL',
                  hintText: 'http://localhost:4000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: On Android Emulator use http://10.0.2.2:4000 to reach a local eis_server REST bridge.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_mode == EisBackendMode.embedded) {
              Navigator.of(context).pop(IesApiClient());
              return;
            }
            if (_mode == EisBackendMode.serverpod) {
              Navigator.of(context).pop(buildServerpodApiClient(_urlCtrl.text));
              return;
            }
            final url = _urlCtrl.text.trim().isEmpty
                ? 'http://localhost:4000'
                : _urlCtrl.text.trim();
            Navigator.of(context).pop(
              IesApiClient(baseUrl: url, useRemoteRest: true),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/*
// Original Flutter starter template preserved per Code Modification & Deprecation Policy:
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
*/
