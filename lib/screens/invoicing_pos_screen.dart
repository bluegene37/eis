// Gene - Nov, 20, 2026: Ported from eis_flutter screens.
// Gene - Nov, 20, 2026: Upgraded Invoicing / POS with Soft UI 2.0 SectionCard icons and recessed EOPT preview & transmission result wells.
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import '../models/ies_models.dart';
import '../services/ies_api_client.dart';
import '../theme/eis_neumorphic_theme.dart';
import '../widgets/neumorphic_widgets.dart';
import '../widgets/shared_components.dart';

class InvoicingPosScreen extends StatefulWidget {
  final TaxpayerProfileModel? activeTaxpayer;
  final IesApiClient api;
  final VoidCallback onInvoiceCreated;

  const InvoicingPosScreen({
    super.key,
    required this.activeTaxpayer,
    required this.api,
    required this.onInvoiceCreated,
  });

  @override
  State<InvoicingPosScreen> createState() => _InvoicingPosScreenState();
}

class _InvoicingPosScreenState extends State<InvoicingPosScreen> {
  final _buyerNameCtrl = TextEditingController(text: 'Manila Enterprise Corp.');
  final _buyerTinCtrl = TextEditingController(text: '008222333');
  final _oscaIdCtrl = TextEditingController();
  final _itemNameCtrl = TextEditingController(text: 'Enterprise Cloud POS License');
  final _qtyCtrl = TextEditingController(text: '1');
  final _unitPriceCtrl = TextEditingController(text: '50000');

  String _systemType = 'CAS';
  String _docType = '01';
  String _transClass = 'B2B';
  String _buyerCategory = 'REGULAR';
  String _taxClassification = 'VATABLE';
  String? _atcCode = 'WC160';
  String _branchCd = '0000';
  bool _priceIncludesVat = false;
  bool _isPaid = false;
  bool _submitting = false;
  StoredInvoiceModel? _lastCreated;

  @override
  void dispose() {
    _buyerNameCtrl.dispose();
    _buyerTinCtrl.dispose();
    _oscaIdCtrl.dispose();
    _itemNameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitPriceCtrl.dispose();
    super.dispose();
  }

  Map<String, double> get _preview {
    return EoptPreviewCalculator.compute(
      qty: double.tryParse(_qtyCtrl.text) ?? 1,
      unitPrice: double.tryParse(_unitPriceCtrl.text) ?? 0,
      priceIncludesVat: _priceIncludesVat,
      taxClassification: _taxClassification,
      buyerCategory: _buyerCategory,
      atcCode: _atcCode,
    );
  }

  Future<void> _submit({bool forceInvalid = false}) async {
    setState(() => _submitting = true);
    try {
      final created = await widget.api.createInvoice({
        if (widget.activeTaxpayer != null) 'taxpayerId': widget.activeTaxpayer!.id,
        'branchCd': _branchCd,
        'sourceSystem': 'IES_UI',
        'systemType': _systemType,
        'docType': _docType,
        'transClass': _transClass,
        'isPaid': _isPaid,
        'buyerName': _buyerNameCtrl.text.trim(),
        'buyerTin': _buyerTinCtrl.text.trim().isEmpty ? null : _buyerTinCtrl.text.trim(),
        'buyerCategory': _buyerCategory,
        'osacaPwdId': _oscaIdCtrl.text.trim().isEmpty ? null : _oscaIdCtrl.text.trim(),
        'forceInvalidPayload': forceInvalid,
        'items': [
          {
            'itemNm': _itemNameCtrl.text.trim(),
            'qty': double.tryParse(_qtyCtrl.text) ?? 1,
            'unitPrice': double.tryParse(_unitPriceCtrl.text) ?? 0,
            'priceIncludesVat': _priceIncludesVat,
            'taxClassification': _taxClassification,
            'atcCode': _atcCode,
          },
        ],
      });
      setState(() => _lastCreated = created);
      widget.onInvoiceCreated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'BIR EIS Response: ${created.ackCode} (${created.eisUniqueId})',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = widget.activeTaxpayer?.branches ?? const [];
    final preview = _preview;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // SectionCard(
        //   title: 'EOPT (RR 7-2024) Sales / Service Invoice & POS Builder',
        SectionCard(
          icon: Icons.point_of_sale_rounded,
          title: 'EOPT (RR 7-2024) Sales / Service Invoice & POS Builder',
          subtitle:
              'Automatically computes 12% VAT, Senior Citizen / PWD 20% VAT-Exempt discounts, Zero-Rated, and RR 6-2026 CWT ATC.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Gene - Nov, 20, 2026: Added isExpanded: true and ellipsis overflow so DropdownButtonFormField never overflows inside SizedBox constraints.
                  // SizedBox(
                  //   width: 180,
                  //   child: DropdownButtonFormField<String>(
                  //     initialValue: _systemType,
                  //     decoration: const InputDecoration(
                  //       labelText: 'BIR Profile',
                  //       border: OutlineInputBorder(),
                  //     ),
                  //     items: const [
                  //       DropdownMenuItem(value: 'CAS', child: Text('CAS v2.01')),
                  //       DropdownMenuItem(value: 'POS', child: Text('CRM / POS v2.01')),
                  //     ],
                  //     onChanged: (v) => setState(() => _systemType = v ?? 'CAS'),
                  //   ),
                  // ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _systemType,
                      decoration: const InputDecoration(
                        labelText: 'BIR Profile',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CAS',
                          child: Text('CAS v2.01', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'POS',
                          child: Text('CRM / POS v2.01', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (v) => setState(() => _systemType = v ?? 'CAS'),
                    ),
                  ),
                  // SizedBox(
                  //   width: 210,
                  //   child: DropdownButtonFormField<String>(
                  //     initialValue: _docType,
                  //     decoration: const InputDecoration(
                  //       labelText: 'Document Type (RR 7-2024)',
                  //       border: OutlineInputBorder(),
                  //     ),
                  //     items: const [
                  //       DropdownMenuItem(value: '01', child: Text('01 - Sales Invoice')),
                  //       DropdownMenuItem(value: '02', child: Text('02 - Service Invoice')),
                  //     ],
                  //     onChanged: (v) => setState(() => _docType = v ?? '01'),
                  //   ),
                  // ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _docType,
                      decoration: const InputDecoration(
                        labelText: 'Document Type (RR 7-2024)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '01',
                          child: Text('01 - Sales Invoice', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: '02',
                          child: Text('02 - Service Invoice', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (v) => setState(() => _docType = v ?? '01'),
                    ),
                  ),
                  // SizedBox(
                  //   width: 170,
                  //   child: DropdownButtonFormField<String>(
                  //     initialValue: _transClass,
                  //     decoration: const InputDecoration(
                  //       labelText: 'Transaction Class',
                  //       border: OutlineInputBorder(),
                  //     ),
                  //     items: const [
                  //       DropdownMenuItem(value: 'B2B', child: Text('B2B')),
                  //       DropdownMenuItem(value: 'B2C', child: Text('B2C')),
                  //       DropdownMenuItem(value: 'EXPORT', child: Text('EXPORT')),
                  //       DropdownMenuItem(value: 'GOVT', child: Text('GOVT')),
                  //     ],
                  //     onChanged: (v) => setState(() => _transClass = v ?? 'B2B'),
                  //   ),
                  // ),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _transClass,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Class',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'B2B', child: Text('B2B')),
                        DropdownMenuItem(value: 'B2C', child: Text('B2C')),
                        DropdownMenuItem(value: 'EXPORT', child: Text('EXPORT')),
                        DropdownMenuItem(value: 'GOVT', child: Text('GOVT')),
                      ],
                      onChanged: (v) => setState(() => _transClass = v ?? 'B2B'),
                    ),
                  ),
                  // if (branches.isNotEmpty)
                  //   SizedBox(
                  //     width: 220,
                  //     child: DropdownButtonFormField<String>(
                  //       initialValue: branches.any((b) => b.branchCd == _branchCd)
                  //           ? _branchCd
                  //           : branches.first.branchCd,
                  //       decoration: const InputDecoration(
                  //         labelText: 'Issuing Branch Code',
                  //         border: OutlineInputBorder(),
                  //       ),
                  //       items: branches
                  //           .map((b) => DropdownMenuItem(
                  //                 value: b.branchCd,
                  //                 child: Text('${b.branchCd} - ${b.branchName}'),
                  //               ))
                  //           .toList(),
                  //       onChanged: (v) => setState(() => _branchCd = v ?? '0000'),
                  //     ),
                  //   ),
                  if (branches.isNotEmpty)
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: branches.any((b) => b.branchCd == _branchCd)
                            ? _branchCd
                            : branches.first.branchCd,
                        decoration: const InputDecoration(
                          labelText: 'Issuing Branch Code',
                          border: OutlineInputBorder(),
                        ),
                        items: branches
                            .map((b) => DropdownMenuItem(
                                  value: b.branchCd,
                                  child: Text(
                                    '${b.branchCd} - ${b.branchName}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _branchCd = v ?? '0000'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _buyerNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Buyer Registered Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _buyerTinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Buyer TIN (9 digits)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  // Gene - Nov, 20, 2026: Added isExpanded: true and ellipsis overflow to prevent Buyer Category DropdownButtonFormField RenderFlex overflow.
                  // SizedBox(
                  //   width: 210,
                  //   child: DropdownButtonFormField<String>(
                  //     initialValue: _buyerCategory,
                  //     decoration: const InputDecoration(
                  //       labelText: 'Buyer Category',
                  //       border: OutlineInputBorder(),
                  //     ),
                  //     items: const [
                  //       DropdownMenuItem(value: 'REGULAR', child: Text('Regular')),
                  //       DropdownMenuItem(
                  //           value: 'SENIOR_CITIZEN', child: Text('Senior Citizen (20% Off)')),
                  //       DropdownMenuItem(value: 'PWD', child: Text('PWD (20% Off)')),
                  //       DropdownMenuItem(value: 'SOLO_PARENT', child: Text('Solo Parent')),
                  //     ],
                  //     onChanged: (v) => setState(() => _buyerCategory = v ?? 'REGULAR'),
                  //   ),
                  // ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _buyerCategory,
                      decoration: const InputDecoration(
                        labelText: 'Buyer Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'REGULAR',
                          child: Text('Regular', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'SENIOR_CITIZEN',
                          child: Text('Senior Citizen (20% Off)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'PWD',
                          child: Text('PWD (20% Off)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'SOLO_PARENT',
                          child: Text('Solo Parent', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (v) => setState(() => _buyerCategory = v ?? 'REGULAR'),
                    ),
                  ),
                  if (_buyerCategory == 'SENIOR_CITIZEN' || _buyerCategory == 'PWD')
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _oscaIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'OSCA / PWD ID #',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _itemNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Item / Service Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _unitPriceCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Unit Price (PHP)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  // Gene - Nov, 20, 2026: Added isExpanded: true and ellipsis overflow to VAT Classification & CWT ATC DropdownButtonFormFields.
                  // SizedBox(
                  //   width: 180,
                  //   child: DropdownButtonFormField<String>(
                  //     initialValue: _taxClassification,
                  //     decoration: const InputDecoration(
                  //       labelText: 'VAT Classification',
                  //       border: OutlineInputBorder(),
                  //     ),
                  //     items: const [
                  //       DropdownMenuItem(value: 'VATABLE', child: Text('12% VATable')),
                  //       DropdownMenuItem(value: 'VAT_EXEMPT', child: Text('VAT-Exempt')),
                  //       DropdownMenuItem(value: 'ZERO_RATED', child: Text('Zero-Rated (0%)')),
                  //     ],
                  //     onChanged: (v) => setState(() => _taxClassification = v ?? 'VATABLE'),
                  //   ),
                  // ),
                  // SizedBox(
                  //   width: 210,
                  //   child: DropdownButtonFormField<String?>(
                  //     initialValue: _atcCode,
                  //     decoration: const InputDecoration(
                  //       labelText: 'CWT ATC (RR 6-2026)',
                  //       border: OutlineInputBorder(),
                  //     ),
                  //     items: const [
                  //       DropdownMenuItem(value: null, child: Text('None (No CWT)')),
                  //       DropdownMenuItem(value: 'WC160', child: Text('WC160 - Services (2%)')),
                  //       DropdownMenuItem(value: 'WC158', child: Text('WC158 - Goods (1%)')),
                  //       DropdownMenuItem(value: 'WI010', child: Text('WI010 - Prof Ind (5%)')),
                  //       DropdownMenuItem(value: 'WC010', child: Text('WC010 - Prof Corp (10%)')),
                  //       DropdownMenuItem(value: 'WC100', child: Text('WC100 - Rentals (5%)')),
                  //     ],
                  //     onChanged: (v) => setState(() => _atcCode = v),
                  //   ),
                  // ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _taxClassification,
                      decoration: const InputDecoration(
                        labelText: 'VAT Classification',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'VATABLE',
                          child: Text('12% VATable', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'VAT_EXEMPT',
                          child: Text('VAT-Exempt', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'ZERO_RATED',
                          child: Text('Zero-Rated (0%)', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (v) => setState(() => _taxClassification = v ?? 'VATABLE'),
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: _atcCode,
                      decoration: const InputDecoration(
                        labelText: 'CWT ATC (RR 6-2026)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('None (No CWT)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'WC160',
                          child: Text('WC160 - Services (2%)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'WC158',
                          child: Text('WC158 - Goods (1%)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'WI010',
                          child: Text('WI010 - Prof Ind (5%)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'WC010',
                          child: Text('WC010 - Prof Corp (10%)', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'WC100',
                          child: Text('WC100 - Rentals (5%)', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (v) => setState(() => _atcCode = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                children: [
                  FilterChip(
                    selected: _priceIncludesVat,
                    label: const Text('Unit Price is VAT-Inclusive'),
                    onSelected: (v) => setState(() => _priceIncludesVat = v),
                  ),
                  FilterChip(
                    selected: _isPaid,
                    label: const Text('Paid Immediately (Cash / POS)'),
                    onSelected: (v) => setState(() => _isPaid = v),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Live EOPT Calculation Preview Bar
              // Wrap(
              //   spacing: 24,
              //   runSpacing: 8,
              //   children: [
              //     _metricChip('Gross Sales', formatPhp(preview['gross'] ?? 0)),
              //     _metricChip('SC/PWD Discount', formatPhp(preview['discount'] ?? 0)),
              //     _metricChip('Net Sales', formatPhp(preview['netSales'] ?? 0)),
              //     _metricChip('12% VAT', formatPhp(preview['vat'] ?? 0)),
              //     _metricChip('CWT Withheld', formatPhp(preview['cwt'] ?? 0)),
              //     _metricChip('Net Amount Due', formatPhp(preview['totalDue'] ?? 0),
              //         bold: true),
              //   ],
              // ),
              // Gene - Nov, 20, 2026: Recessed NeumorphicWell EOPT calculation bar with accent Net Amount Due pill.
              NeumorphicWell(
                borderRadius: 16,
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _metricChip(context, 'Gross Sales', formatPhp(preview['gross'] ?? 0)),
                    _metricChip(context, 'SC/PWD Discount', formatPhp(preview['discount'] ?? 0)),
                    _metricChip(context, 'Net Sales', formatPhp(preview['netSales'] ?? 0)),
                    _metricChip(context, '12% VAT', formatPhp(preview['vat'] ?? 0)),
                    _metricChip(context, 'CWT Withheld', formatPhp(preview['cwt'] ?? 0)),
                    _metricChip(
                      context,
                      'Net Amount Due',
                      formatPhp(preview['totalDue'] ?? 0),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _submitting ? null : () => _submit(),
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      _submitting
                          ? 'Signing JWS & Encrypting...'
                          : 'Sign JWS, Encrypt AES-256 & Transmit to BIR EIS',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : () => _submit(forceInvalid: true),
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Test SYN004 Validation Rejection'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_lastCreated != null) ...[
          const SizedBox(height: 16),
          // SectionCard(
          //   title: 'Last BIR EIS Transmission Result (${_lastCreated!.ackCode})',
          //   subtitle: 'EisUniqueId: ${_lastCreated!.eisUniqueId}',
          //   trailing: StatusBadge(
          //     label: _lastCreated!.ackCode,
          //     color: statusColor(context, _lastCreated!.status),
          //   ),
          //   child: SelectableText(
          //     const JsonEncoder.withIndent('  ').convert({
          //       'receipt': _lastCreated!.lastReceipt,
          //       'payload': _lastCreated!.payload,
          //     }),
          //     style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          //   ),
          // ),
          // Gene - Nov, 20, 2026: Added icon and recessed NeumorphicWell for last transmission JSON.
          SectionCard(
            icon: Icons.receipt_rounded,
            title: 'Last BIR EIS Transmission Result (${_lastCreated!.ackCode})',
            subtitle: 'EisUniqueId: ${_lastCreated!.eisUniqueId}',
            trailing: StatusBadge(
              label: _lastCreated!.ackCode,
              color: statusColor(context, _lastCreated!.status),
            ),
            child: NeumorphicWell(
              borderRadius: 14,
              padding: const EdgeInsets.all(14),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert({
                  'receipt': _lastCreated!.lastReceipt,
                  'payload': _lastCreated!.payload,
                }),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Widget _metricChip(String label, String val, {bool bold = false}) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  //       Text(
  //         val,
  //         style: TextStyle(
  //           fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
  //           fontSize: bold ? 15 : 13,
  //           fontFeatures: const [FontFeature.tabularFigures()],
  //         ),
  //       ),
  //     ],
  //   );
  // }
  Widget _metricChip(
    BuildContext context,
    String label,
    String val, {
    bool bold = false,
  }) {
    final tokens = EisNeumorphicTokens.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            color: bold ? tokens.accentPrimary : tokens.textPrimary,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 16 : 13.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    if (!bold) return content;
    return NeumorphicSurface(
      depth: NeumorphicDepth.subtle,
      borderRadius: 12,
      tintColor: tokens.accentPrimary,
      borderColor: tokens.accentPrimary.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: content,
    );
  }
}
