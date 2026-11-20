// Gene - Nov, 20, 2026: Ported from eis_flutter screens.
import 'package:material_ui/material_ui.dart';
import '../models/ies_models.dart';
import '../services/ies_api_client.dart';
import '../widgets/shared_components.dart';

class VaultAuditScreen extends StatefulWidget {
  final List<TaxpayerProfileModel> taxpayers;
  final IesApiClient api;
  final VoidCallback onRefresh;
  // Gene - Nov, 20, 2026: Added refreshNonce so parent actions and backend switches refresh the Annex B audit trail automatically.
  final int refreshNonce;

  // const VaultAuditScreen({
  //   super.key,
  //   required this.taxpayers,
  //   required this.api,
  //   required this.onRefresh,
  // });
  const VaultAuditScreen({
    super.key,
    required this.taxpayers,
    required this.api,
    required this.onRefresh,
    this.refreshNonce = 0,
  });

  @override
  State<VaultAuditScreen> createState() => _VaultAuditScreenState();
}

class _VaultAuditScreenState extends State<VaultAuditScreen> {
  AuditTrailResponseModel? _audit;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAudit();
  }

  // Gene - Nov, 20, 2026: Reload Annex B audit trail when refreshNonce or API client changes.
  @override
  void didUpdateWidget(covariant VaultAuditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce ||
        oldWidget.api != widget.api) {
      _loadAudit();
    }
  }

  Future<void> _loadAudit() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.fetchAuditTrail();
      if (mounted) setState(() => _audit = res);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionCard(
          title: 'Multi-TIN / Multi-Branch Cryptographic Key Vault',
          subtitle:
              'Per-TIN isolated RSA-2048 X.509 JWS signing keys, AES-256 transport secrets, EIS Cert IDs & Permit to Transmit (PTT).',
          child: Column(
            children: widget.taxpayers.map((tp) {
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainer,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${tp.registeredName} (TIN: ${tp.tin})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                          StatusBadge(
                            label: '${tp.taxType} | ${tp.eisCertId}',
                            color: const Color(0xFF0F766E),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PTT: ${tp.pttNumber}   |   Active JWS Key ID: ${tp.keyId}',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tp.branches.map((b) {
                          return Chip(
                            label: Text(
                              'Branch ${b.branchCd} (${b.branchName}) • Seq #${b.lastSequence}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await widget.api.rotateTaxpayerKeys(tp.id);
                              widget.onRefresh();
                              _loadAudit();
                            },
                            icon: const Icon(Icons.vpn_key_outlined, size: 16),
                            label: const Text('Rotate RSA-2048 JWS & AES-256 Keys'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'RMC 5-2021 Annex B Immutable Audit Trail (SHA-256 Hash Chain)',
          subtitle:
              'Tamper-evident sequential activity log linking prevHash -> entryHash across all EIS & CAS actions.',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_audit != null)
                StatusBadge(
                  label: _audit!.valid
                      ? 'CHAIN VERIFIED (${_audit!.totalEntries})'
                      : 'TAMPER DETECTED AT SEQ ${_audit!.brokenAtSeq}',
                  color: _audit!.valid
                      ? const Color(0xFF0F766E)
                      : Theme.of(context).colorScheme.error,
                  icon: _audit!.valid ? Icons.verified_user : Icons.warning_amber,
                ),
              IconButton(
                onPressed: _loadAudit,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          child: _loading || _audit == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: _audit!.entries.take(25).map((e) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${e.seq}', style: const TextStyle(fontSize: 11)),
                      ),
                      title: Text(
                        '${e.action}  •  ${e.entityId}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${e.timestamp} | Actor: ${e.actor}\n${e.details}\nSHA-256: ${e.entryHash.substring(0, 24)}...',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
