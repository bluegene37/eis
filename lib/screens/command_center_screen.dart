// Gene - Nov, 20, 2026: Ported from eis_flutter screens.
// Gene - Nov, 20, 2026: Upgraded Command Center with Soft UI 2.0 neumorphic banner, theme-aware KPIs, recessed ledger table, and copyable payload inspector.
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../models/ies_models.dart';
import '../services/ies_api_client.dart';
import '../theme/eis_neumorphic_theme.dart';
import '../widgets/neumorphic_widgets.dart';
import '../widgets/shared_components.dart';

class CommandCenterScreen extends StatelessWidget {
  final DashboardSummaryModel? summary;
  final List<StoredInvoiceModel> invoices;
  final IesApiClient api;
  final VoidCallback onRefresh;

  const CommandCenterScreen({
    super.key,
    required this.summary,
    required this.invoices,
    required this.api,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null) {
      return const Center(child: CircularProgressIndicator());
    }

//     return ListView(
//       padding: const EdgeInsets.all(20),
//       children: [
//         // KPI Grid
//         LayoutBuilder(
//           builder: (context, constraints) {
//             final cols = constraints.maxWidth > 950
//                 ? 4
//                 : constraints.maxWidth > 600
//                     ? 2
//                     : 1;
//             final cardWidth = (constraints.maxWidth - (cols - 1) * 12) / cols;
//             return Wrap(
//               spacing: 12,
//               runSpacing: 12,
//               children: [
//                 SizedBox(
//                   width: cardWidth,
//                   child: KpiCard(
//                     label: 'EIS TRANSMITTED (ACK-200)',
//                     value: '${s.transmittedCount} / ${s.totalInvoices}',
//                     subtitle: 'Schema v2.01 JWS + AES-256',
//                     icon: Icons.verified_rounded,
//                     accentColor: const Color(0xFF0F766E),
//                   ),
//                 ),
//                 SizedBox(
//                   width: cardWidth,
//                   child: KpiCard(
//                     label: '3-DAY RETRY QUEUE',
//                     value: '${s.queuedRetryCount}',
//                     subtitle: s.rejectedCount > 0
//                         ? '${s.rejectedCount} rejected (SYN004/VAL001)'
//                         : '0 schema rejections',
//                     icon: Icons.schedule_send_rounded,
//                     accentColor: s.queuedRetryCount > 0
//                         ? const Color(0xFFB45309)
//                         : const Color(0xFF1D4ED8),
//                   ),
//                 ),
//                 SizedBox(
//                   width: cardWidth,
//                   child: KpiCard(
//                     label: 'OUTPUT VAT (12%)',
//                     value: formatPhp(s.totalOutputVatPhp),
//                     subtitle: 'Net Sales: ${formatPhp(s.totalSalesPhp)}',
//                     icon: Icons.account_balance_rounded,
//                     accentColor: const Color(0xFF1E3A8A),
//                   ),
//                 ),
//                 SizedBox(
//                   width: cardWidth,
//                   child: KpiCard(
//                     label: 'CWT / EWT (RR 6-2026)',
//                     value: formatPhp(s.totalCwtPhp),
//                     subtitle: s.auditChainValid
//                         ? 'Annex B Chain: VALID (${s.auditTotalEntries})'
//                         : 'Annex B Chain: ALERT',
//                     icon: Icons.security_rounded,
//                     accentColor: s.auditChainValid
//                         ? const Color(0xFF0F766E)
//                         : Theme.of(context).colorScheme.error,
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//         const SizedBox(height: 16),
//
//         // 3-Tier BIR EIS Gateway & Simulator Controls
//         SectionCard(
//           title: '3-Tier BIR EIS Gateway Router & 3-Day SLA Queue Tester',
//           subtitle:
//               'Switch between Built-in Spec-Faithful Simulator, Certification Sandbox (eis-cert.bir.gov.ph), and Production (eis.bir.gov.ph)',
//           trailing: FilledButton.icon(
//             onPressed: () async {
//               final res = await api.processRetryQueue();
//               if (context.mounted) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(
//                       'Retry Queue: processed ${res['processed']}, succeeded ${res['succeeded']}',
//                     ),
//                   ),
//                 );
//               }
//               onRefresh();
//             },
//             icon: const Icon(Icons.replay_circle_filled_rounded),
//             label: const Text('Flush 3-Day Retry Queue'),
//           ),
//           child: Wrap(
//             spacing: 12,
//             runSpacing: 12,
//             crossAxisAlignment: WrapCrossAlignment.center,
//             children: [
//               SegmentedButton<String>(
//                 segments: const [
//                   ButtonSegment(
//                     value: 'MOCK_BIR_SIMULATOR',
//                     label: Text('1. Built-in BIR Simulator'),
//                     icon: Icon(Icons.science_outlined),
//                   ),
//                   ButtonSegment(
//                     value: 'BIR_CERT_SANDBOX',
//                     label: Text('2. eis-cert.bir.gov.ph'),
//                     icon: Icon(Icons.verified_user_outlined),
//                   ),
//                   ButtonSegment(
//                     value: 'BIR_PRODUCTION',
//                     label: Text('3. eis.bir.gov.ph'),
//                     icon: Icon(Icons.public_rounded),
//                   ),
//                 ],
//                 selected: {s.gatewayMode},
//                 onSelectionChanged: (sel) async {
//                   await api.updateGatewayConfig(mode: sel.first);
//                   onRefresh();
//                 },
//               ),
//               FilterChip(
//                 selected: s.simulateOutage,
//                 label: Text(
//                   s.simulateOutage
//                       ? 'BIR Outage Simulated (NET503 Active)'
//                       : 'Simulate BIR Outage (Test 3-Day Queue)',
//                 ),
//                 avatar: Icon(
//                   s.simulateOutage ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
//                   size: 18,
//                 ),
//                 onSelected: (val) async {
//                   await api.updateGatewayConfig(simulateOutage: val);
//                   onRefresh();
//                 },
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//
//         // Recent EIS Transmissions & Payload Inspector
//         SectionCard(
//           title: 'BIR EIS v2.01 Transmission Ledger',
//           subtitle:
//               'Every synced or native invoice is signed with RS256 JWS, encrypted with AES-256-GCM, and validated before BIR submission.',
//           child: SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: DataTable(
//               headingRowHeight: 40,
//               dataRowMinHeight: 48,
//               dataRowMaxHeight: 56,
//               columns: const [
//                 DataColumn(label: Text('Source')),
//                 DataColumn(label: Text('Invoice #')),
//                 DataColumn(label: Text('24-Char EisUniqueId')),
//                 DataColumn(label: Text('Counterparty')),
//                 DataColumn(label: Text('Net Sales'), numeric: true),
//                 DataColumn(label: Text('12% VAT'), numeric: true),
//                 DataColumn(label: Text('CWT'), numeric: true),
//                 DataColumn(label: Text('BIR Status')),
//                 DataColumn(label: Text('Inspect')),
//               ],
//               rows: invoices.map((inv) {
//                 return DataRow(
//                   cells: [
//                     DataCell(Chip(
//                       label: Text(inv.sourceSystem, style: const TextStyle(fontSize: 11)),
//                       visualDensity: VisualDensity.compact,
//                     )),
//                     DataCell(Text(
//                       inv.compInvoiceId,
//                       style: const TextStyle(fontWeight: FontWeight.w600),
//                     )),
//                     DataCell(Text(
//                       inv.eisUniqueId,
//                       style: const TextStyle(
//                         fontFamily: 'monospace',
//                         fontSize: 12,
//                       ),
//                     )),
//                     DataCell(Text(inv.buyerName)),
//                     DataCell(Text(formatPhp(inv.summary.netSales))),
//                     DataCell(Text(formatPhp(inv.summary.vatAmt))),
//                     DataCell(Text(formatPhp(inv.summary.withholdingTaxAmt))),
//                     DataCell(StatusBadge(
//                       label: inv.ackCode,
//                       color: statusColor(context, inv.status),
//                     )),
//                     DataCell(
//                       IconButton(
//                         tooltip: 'Inspect BIR v2.01 JSON + JWS + AES-256',
//                         icon: const Icon(Icons.code_rounded),
//                         onPressed: () => _showPayloadDialog(context, inv),
//                       ),
//                     ),
//                   ],
//                 );
//               }).toList(),
//             ),
//           ),
//         ),
//       ],
//     );
    // Gene - Nov, 20, 2026: Added Compliance Overview Banner, theme-aware KPI accents, SectionCard icons, and recessed DataTable well.
    final tokens = EisNeumorphicTokens.of(context);
    const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

    // Gene - Nov, 20, 2026: Use SingleChildScrollView + Column and responsive LayoutBuilder banner so narrow mobile widths never overflow and ledger rows remain mounted.
    // return ListView(
    //   padding: const EdgeInsets.all(20),
    //   children: [
    //     // Compliance Overview Banner
    //     NeumorphicSurface(
    //       depth: NeumorphicDepth.raised,
    //       borderRadius: 20,
    //       tintColor: tokens.accentPrimary,
    //       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    //       child: Wrap(
    //         spacing: 12,
    //         runSpacing: 10,
    //         alignment: WrapAlignment.spaceBetween,
    //         crossAxisAlignment: WrapCrossAlignment.center,
    //         children: [
    //           Row(
    //             mainAxisSize: MainAxisSize.min,
    //             children: [
    //               NeumorphicIconBadge(
    //                 icon: Icons.verified_user_rounded,
    //                 color: tokens.accentPrimary,
    //                 size: 40,
    //                 iconSize: 20,
    //               ),
    //               const SizedBox(width: 12),
    //               Column(
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   Text(
    //                     'BIR EIS Compliance Command Center',
    //                     style: Theme.of(context).textTheme.titleMedium?.copyWith(
    //                           color: tokens.textPrimary,
    //                           fontWeight: FontWeight.w700,
    //                         ),
    //                   ),
    //                   Text(
    //                     'Active Schema: BIR EIS v2.01 • JWS RS256 + AES-256-GCM • EOPT & CAS',
    //                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
    //                           color: tokens.textSecondary,
    //                         ),
    //                   ),
    //                 ],
    //               ),
    //             ],
    //           ),
    //           Wrap(
    //             spacing: 8,
    //             runSpacing: 8,
    //             children: [
    //               StatusBadge(
    //                 label: s.gatewayMode,
    //                 color: s.simulateOutage ? tokens.warning : tokens.success,
    //               ),
    //               StatusBadge(
    //                 label: 'EIS v2.01',
    //                 color: tokens.accentSecondary,
    //                 icon: Icons.shield_outlined,
    //               ),
    //             ],
    //           ),
    //         ],
    //       ),
    //     ),
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compliance Overview Banner
          NeumorphicSurface(
            depth: NeumorphicDepth.raised,
            borderRadius: 20,
            tintColor: tokens.accentPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final titleRow = Row(
                  children: [
                    NeumorphicIconBadge(
                      icon: Icons.verified_user_rounded,
                      color: tokens.accentPrimary,
                      size: 40,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BIR EIS Compliance Command Center',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            'Active Schema: BIR EIS v2.01 • JWS RS256 + AES-256-GCM • EOPT & CAS',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final badges = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: s.gatewayMode,
                      color: s.simulateOutage ? tokens.warning : tokens.success,
                    ),
                    StatusBadge(
                      label: 'EIS v2.01',
                      color: tokens.accentSecondary,
                      icon: Icons.shield_outlined,
                    ),
                  ],
                );
                if (constraints.maxWidth >= 680) {
                  return Row(
                    children: [
                      Expanded(child: titleRow),
                      const SizedBox(width: 12),
                      badges,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleRow,
                    const SizedBox(height: 10),
                    badges,
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 18),

        // KPI Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 950
                ? 4
                : constraints.maxWidth > 600
                    ? 2
                    : 1;
            final cardWidth = (constraints.maxWidth - (cols - 1) * 14) / cols;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: KpiCard(
                    label: 'EIS TRANSMITTED (ACK-200)',
                    value: '${s.transmittedCount} / ${s.totalInvoices}',
                    subtitle: 'Schema v2.01 JWS + AES-256',
                    icon: Icons.verified_rounded,
                    accentColor: tokens.success,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: KpiCard(
                    label: '3-DAY RETRY QUEUE',
                    value: '${s.queuedRetryCount}',
                    subtitle: s.rejectedCount > 0
                        ? '${s.rejectedCount} rejected (SYN004/VAL001)'
                        : '0 schema rejections',
                    icon: Icons.schedule_send_rounded,
                    accentColor: s.queuedRetryCount > 0
                        ? tokens.warning
                        : tokens.accentSecondary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: KpiCard(
                    label: 'OUTPUT VAT (12%)',
                    value: formatPhp(s.totalOutputVatPhp),
                    subtitle: 'Net Sales: ${formatPhp(s.totalSalesPhp)}',
                    icon: Icons.account_balance_rounded,
                    accentColor: tokens.accentSecondary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: KpiCard(
                    label: 'CWT / EWT (RR 6-2026)',
                    value: formatPhp(s.totalCwtPhp),
                    subtitle: s.auditChainValid
                        ? 'Annex B Chain: VALID (${s.auditTotalEntries})'
                        : 'Annex B Chain: ALERT',
                    icon: Icons.security_rounded,
                    accentColor: s.auditChainValid ? tokens.success : tokens.danger,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // 3-Tier BIR EIS Gateway & Simulator Controls
        SectionCard(
          icon: Icons.router_rounded,
          title: '3-Tier BIR EIS Gateway Router & 3-Day SLA Queue Tester',
          subtitle:
              'Switch between Built-in Spec-Faithful Simulator, Certification Sandbox (eis-cert.bir.gov.ph), and Production (eis.bir.gov.ph)',
          trailing: FilledButton.icon(
            onPressed: () async {
              final res = await api.processRetryQueue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Retry Queue: processed ${res['processed']}, succeeded ${res['succeeded']}',
                    ),
                  ),
                );
              }
              onRefresh();
            },
            icon: const Icon(Icons.replay_circle_filled_rounded),
            label: const Text('Flush 3-Day Retry Queue'),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'MOCK_BIR_SIMULATOR',
                      label: Text('1. Built-in BIR Simulator'),
                      icon: Icon(Icons.science_outlined),
                    ),
                    ButtonSegment(
                      value: 'BIR_CERT_SANDBOX',
                      label: Text('2. eis-cert.bir.gov.ph'),
                      icon: Icon(Icons.verified_user_outlined),
                    ),
                    ButtonSegment(
                      value: 'BIR_PRODUCTION',
                      label: Text('3. eis.bir.gov.ph'),
                      icon: Icon(Icons.public_rounded),
                    ),
                  ],
                  selected: {s.gatewayMode},
                  onSelectionChanged: (sel) async {
                    await api.updateGatewayConfig(mode: sel.first);
                    onRefresh();
                  },
                ),
              ),
              FilterChip(
                selected: s.simulateOutage,
                label: Text(
                  s.simulateOutage
                      ? 'BIR Outage Simulated (NET503 Active)'
                      : 'Simulate BIR Outage (Test 3-Day Queue)',
                ),
                avatar: Icon(
                  s.simulateOutage ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                  size: 18,
                ),
                onSelected: (val) async {
                  await api.updateGatewayConfig(simulateOutage: val);
                  onRefresh();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Recent EIS Transmissions & Payload Inspector
        SectionCard(
          icon: Icons.receipt_long_rounded,
          title: 'BIR EIS v2.01 Transmission Ledger',
          subtitle:
              'Every synced or native invoice is signed with RS256 JWS, encrypted with AES-256-GCM, and validated before BIR submission.',
          child: NeumorphicWell(
            borderRadius: 14,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 42,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('Source')),
                    DataColumn(label: Text('Invoice #')),
                    DataColumn(label: Text('24-Char EisUniqueId')),
                    DataColumn(label: Text('Counterparty')),
                    DataColumn(label: Text('Net Sales'), numeric: true),
                    DataColumn(label: Text('12% VAT'), numeric: true),
                    DataColumn(label: Text('CWT'), numeric: true),
                    DataColumn(label: Text('BIR Status')),
                    DataColumn(label: Text('Inspect')),
                  ],
                  rows: invoices.map((inv) {
                    return DataRow(
                      cells: [
                        DataCell(Chip(
                          label: Text(inv.sourceSystem, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        )),
                        DataCell(Text(
                          inv.compInvoiceId,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )),
                        DataCell(Text(
                          inv.eisUniqueId,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        )),
                        DataCell(Text(inv.buyerName)),
                        DataCell(Text(formatPhp(inv.summary.netSales), style: tabular)),
                        DataCell(Text(formatPhp(inv.summary.vatAmt), style: tabular)),
                        DataCell(Text(formatPhp(inv.summary.withholdingTaxAmt), style: tabular)),
                        DataCell(StatusBadge(
                          label: inv.ackCode,
                          color: statusColor(context, inv.status),
                        )),
                        DataCell(
                          IconButton(
                            tooltip: 'Inspect BIR v2.01 JSON + JWS + AES-256',
                            icon: const Icon(Icons.code_rounded),
                            onPressed: () => _showPayloadDialog(context, inv),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  void _showPayloadDialog(BuildContext context, StoredInvoiceModel inv) {
    final prettyPayload = const JsonEncoder.withIndent('  ').convert(inv.payload);
    final prettyAes = const JsonEncoder.withIndent('  ').convert(inv.aesEnvelope);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('BIR EIS v2.01 Cryptographic Envelope — ${inv.compInvoiceId}'),
        content: SizedBox(
          width: 720,
          height: 520,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'BIR v2.01 JSON'),
                    Tab(text: 'JWS (RS256) Token'),
                    Tab(text: 'AES-256-GCM Envelope'),
                  ],
                ),
//                 Expanded(
//                   child: TabBarView(
//                     children: [
//                       SingleChildScrollView(
//                         padding: const EdgeInsets.all(12),
//                         child: SelectableText(
//                           prettyPayload,
//                           style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
//                         ),
//                       ),
//                       SingleChildScrollView(
//                         padding: const EdgeInsets.all(12),
//                         child: SelectableText(
//                           inv.jwsToken,
//                           style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
//                         ),
//                       ),
//                       SingleChildScrollView(
//                         padding: const EdgeInsets.all(12),
//                         child: SelectableText(
//                           prettyAes,
//                           style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
                // Gene - Nov, 20, 2026: Recessed NeumorphicWell console boxes with Copy button per payload envelope tab.
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildConsoleTab(ctx, prettyPayload, 'BIR v2.01 JSON'),
                      _buildConsoleTab(ctx, inv.jwsToken, 'JWS (RS256) Token'),
                      _buildConsoleTab(ctx, prettyAes, 'AES-256-GCM Envelope'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (inv.docType != '03' && inv.status == 'TRANSMITTED')
            TextButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await api.issueCreditMemo(inv.id, 'Customer Adjustment');
                onRefresh();
              },
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Issue Credit Memo (DocType 03)'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Gene - Nov, 20, 2026: Shared recessed console helper for payload inspector tabs.
  Widget _buildConsoleTab(BuildContext context, String text, String label) {
    return NeumorphicWell(
      borderRadius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied $label to clipboard')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy'),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
