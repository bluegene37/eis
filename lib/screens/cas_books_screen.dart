// Gene - Nov, 20, 2026: Ported from eis_flutter screens.
// Gene - Nov, 20, 2026: Upgraded CAS 6 Books with Soft UI 2.0 icons, recessed Trial Balance table, sculpted journal tiles, and color-coded DR/CR figures.
import 'package:material_ui/material_ui.dart';
import '../models/ies_models.dart';
import '../services/ies_api_client.dart';
import '../theme/eis_neumorphic_theme.dart';
import '../widgets/neumorphic_widgets.dart';
import '../widgets/shared_components.dart';

class CasBooksScreen extends StatefulWidget {
  final TaxpayerProfileModel? activeTaxpayer;
  final IesApiClient api;
  // Gene - Nov, 20, 2026: Added refreshNonce so parent invoice/sync/backend-switch refreshes CAS books automatically.
  final int refreshNonce;

  // const CasBooksScreen({
  //   super.key,
  //   required this.activeTaxpayer,
  //   required this.api,
  // });
  const CasBooksScreen({
    super.key,
    required this.activeTaxpayer,
    required this.api,
    this.refreshNonce = 0,
  });

  @override
  State<CasBooksScreen> createState() => _CasBooksScreenState();
}

class _CasBooksScreenState extends State<CasBooksScreen> {
  String _selectedBook = 'ALL';
  CasBooksDataModel? _books;
  bool _loading = false;

  static const _bookLabels = {
    'ALL': 'All 6 Books (GL Consolidated)',
    'SJ': 'Sales Journal (SJ)',
    'PJ': 'Purchase Journal (PJ)',
    'CRJ': 'Cash Receipts Journal (CRJ)',
    'CDJ': 'Cash Disbursements Journal (CDJ)',
    'GJ': 'General Journal (GJ)',
    'GL': 'General Ledger (GL)',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CasBooksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // if (oldWidget.activeTaxpayer?.id != widget.activeTaxpayer?.id) {
    //   _load();
    // }
    // Gene - Nov, 20, 2026: Reload CAS books when active taxpayer, refreshNonce, or API client changes.
    if (oldWidget.activeTaxpayer?.id != widget.activeTaxpayer?.id ||
        oldWidget.refreshNonce != widget.refreshNonce ||
        oldWidget.api != widget.api) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.fetchCasBooks(
        taxpayerId: widget.activeTaxpayer?.id,
        bookType: _selectedBook,
      );
      if (mounted) setState(() => _books = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

//   @override
//   Widget build(BuildContext context) {
//     final books = _books;
//     return ListView(
//       padding: const EdgeInsets.all(20),
//       children: [
//         SectionCard(
//           title: 'BIR CAS 6 Mandatory Books of Accounts (RR No. 9-2009 & PFRS)',
//           subtitle:
//               'Every BIR EIS invoice, credit memo, or vendor bill automatically posts balanced double-entry journals.',
//           trailing: IconButton(
//             onPressed: _load,
//             icon: const Icon(Icons.refresh_rounded),
//           ),
//           child: Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children: _bookLabels.entries.map((e) {
//               return ChoiceChip(
//                 label: Text(e.value),
//                 selected: _selectedBook == e.key,
//                 onSelected: (_) {
//                   setState(() => _selectedBook = e.key);
//                   _load();
//                 },
//               );
//             }).toList(),
//           ),
//         ),
//         const SizedBox(height: 16),
//         if (_loading || books == null)
//           const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
//         else ...[
//           // PFRS Trial Balance Verification
//           SectionCard(
//             title: 'PFRS General Ledger Trial Balance',
//             subtitle:
//                 'Debits: ${formatPhp(books.totalDebits)}  |  Credits: ${formatPhp(books.totalCredits)}',
//             trailing: StatusBadge(
//               label: books.isBalanced ? 'BALANCED (DR == CR)' : 'UNBALANCED',
//               color: books.isBalanced
//                   ? const Color(0xFF0F766E)
//                   : Theme.of(context).colorScheme.error,
//               icon: books.isBalanced ? Icons.check_circle_outline : Icons.error_outline,
//             ),
//             child: SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: DataTable(
//                 headingRowHeight: 38,
//                 columns: const [
//                   DataColumn(label: Text('Acct Code')),
//                   DataColumn(label: Text('Account Title')),
//                   DataColumn(label: Text('Category')),
//                   DataColumn(label: Text('Total Debit'), numeric: true),
//                   DataColumn(label: Text('Total Credit'), numeric: true),
//                   DataColumn(label: Text('Net Balance'), numeric: true),
//                 ],
//                 rows: books.trialBalanceRows.map((r) {
//                   return DataRow(
//                     cells: [
//                       DataCell(Text(r.accountCode,
//                           style: const TextStyle(fontFamily: 'monospace'))),
//                       DataCell(Text(r.accountName)),
//                       DataCell(Text(r.category)),
//                       DataCell(Text(formatPhp(r.debitTotal))),
//                       DataCell(Text(formatPhp(r.creditTotal))),
//                       DataCell(Text(formatPhp(r.netBalance),
//                           style: const TextStyle(fontWeight: FontWeight.w600))),
//                     ],
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//
//           // Journal Entries List
//           SectionCard(
//             title: 'Book Entries (${books.entries.length})',
//             subtitle: 'Filtered view: ${_bookLabels[_selectedBook]}',
//             child: Column(
//               children: books.entries.map((entry) {
//                 return ExpansionTile(
//                   tilePadding: EdgeInsets.zero,
//                   leading: StatusBadge(
//                     label: entry.bookType,
//                     color: Theme.of(context).colorScheme.primary,
//                   ),
//                   title: Text(
//                     '${entry.referenceNo} — ${entry.counterpartyName}',
//                     style: const TextStyle(fontWeight: FontWeight.w600),
//                   ),
//                   subtitle: Text(
//                     '${entry.entryDate} | ${entry.particulars} | DR/CR: ${formatPhp(entry.totalDebit)}',
//                     style: const TextStyle(fontSize: 12),
//                   ),
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
//                       child: Column(
//                         children: entry.lines.map((ln) {
//                           return Padding(
//                             padding: const EdgeInsets.symmetric(vertical: 3),
//                             child: Row(
//                               children: [
//                                 SizedBox(
//                                   width: 60,
//                                   child: Text(ln.accountCode,
//                                       style: const TextStyle(fontFamily: 'monospace')),
//                                 ),
//                                 Expanded(child: Text(ln.accountName)),
//                                 SizedBox(
//                                   width: 140,
//                                   child: Text(
//                                     ln.debit > 0 ? 'DR ${formatPhp(ln.debit)}' : '',
//                                     textAlign: TextAlign.right,
//                                     style: const TextStyle(fontFamily: 'monospace'),
//                                   ),
//                                 ),
//                                 SizedBox(
//                                   width: 140,
//                                   child: Text(
//                                     ln.credit > 0 ? 'CR ${formatPhp(ln.credit)}' : '',
//                                     textAlign: TextAlign.right,
//                                     style: const TextStyle(fontFamily: 'monospace'),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           );
//                         }).toList(),
//                       ),
//                     ),
//                   ],
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//       ],
//     );
//   }
  @override
  Widget build(BuildContext context) {
    final books = _books;
    final tokens = EisNeumorphicTokens.of(context);
    const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionCard(
          icon: Icons.menu_book_rounded,
          title: 'BIR CAS 6 Mandatory Books of Accounts (RR No. 9-2009 & PFRS)',
          subtitle:
              'Every BIR EIS invoice, credit memo, or vendor bill automatically posts balanced double-entry journals.',
          trailing: IconButton(
            tooltip: 'Refresh CAS Books',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bookLabels.entries.map((e) {
              return ChoiceChip(
                label: Text(e.value),
                selected: _selectedBook == e.key,
                onSelected: (_) {
                  setState(() => _selectedBook = e.key);
                  _load();
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        if (_loading || books == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          // PFRS Trial Balance Verification
          SectionCard(
            icon: Icons.balance_rounded,
            title: 'PFRS General Ledger Trial Balance',
            subtitle:
                'Debits: ${formatPhp(books.totalDebits)}  |  Credits: ${formatPhp(books.totalCredits)}',
            trailing: StatusBadge(
              label: books.isBalanced ? 'BALANCED (DR == CR)' : 'UNBALANCED',
              color: books.isBalanced ? tokens.success : tokens.danger,
              icon: books.isBalanced
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
            ),
            child: NeumorphicWell(
              borderRadius: 14,
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 40,
                    columns: const [
                      DataColumn(label: Text('Acct Code')),
                      DataColumn(label: Text('Account Title')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Total Debit'), numeric: true),
                      DataColumn(label: Text('Total Credit'), numeric: true),
                      DataColumn(label: Text('Net Balance'), numeric: true),
                    ],
                    rows: books.trialBalanceRows.map((r) {
                      return DataRow(
                        cells: [
                          DataCell(Text(
                            r.accountCode,
                            style: const TextStyle(fontFamily: 'monospace'),
                          )),
                          DataCell(Text(r.accountName)),
                          DataCell(Text(r.category)),
                          DataCell(Text(formatPhp(r.debitTotal), style: tabular)),
                          DataCell(Text(formatPhp(r.creditTotal), style: tabular)),
                          DataCell(Text(
                            formatPhp(r.netBalance),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Journal Entries List
          SectionCard(
            icon: Icons.list_alt_rounded,
            title: 'Book Entries (${books.entries.length})',
            subtitle: 'Filtered view: ${_bookLabels[_selectedBook]}',
            child: Column(
              children: books.entries.map((entry) {
                return NeumorphicSurface(
                  depth: NeumorphicDepth.subtle,
                  borderRadius: 16,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: StatusBadge(
                        label: entry.bookType,
                        color: tokens.accentPrimary,
                      ),
                      title: Text(
                        '${entry.referenceNo} — ${entry.counterpartyName}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${entry.entryDate} | ${entry.particulars} | DR/CR: ${formatPhp(entry.totalDebit)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                      children: [
                        NeumorphicWell(
                          borderRadius: 12,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: entry.lines.map((ln) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        ln.accountCode,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Text(ln.accountName)),
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        ln.debit > 0
                                            ? 'DR ${formatPhp(ln.debit)}'
                                            : '',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                          color: tokens.success,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        ln.credit > 0
                                            ? 'CR ${formatPhp(ln.credit)}'
                                            : '',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                          color: tokens.accentSecondary,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
