// Gene - Nov, 24, 2026: Soft UI 2.0 Supabase Auth & Workspace Bootstrap screen
// shown in Supabase mode when unauthenticated or when creating the first workspace.

import 'package:material_ui/material_ui.dart';
import '../services/ies_api_client.dart';
import '../theme/eis_neumorphic_theme.dart';
import '../widgets/neumorphic_widgets.dart';

class SupabaseAuthScreen extends StatefulWidget {
  final IesApiClient api;
  final VoidCallback onAuthenticated;
  final VoidCallback onOpenBackendDialog;
  final VoidCallback onSwitchToLocalEngine;

  const SupabaseAuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
    required this.onOpenBackendDialog,
    required this.onSwitchToLocalEngine,
  });

  @override
  State<SupabaseAuthScreen> createState() => _SupabaseAuthScreenState();
}

class _SupabaseAuthScreenState extends State<SupabaseAuthScreen> {
  bool _isSignUp = false;
  bool _seedDemo = true;
  bool _busy = false;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _workspaceCtrl = TextEditingController(
    text: 'Philippine Enterprise Compliance Hub',
  );

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _workspaceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.length < 6) {
      setState(() {
        _error = 'Enter a valid email and a password of at least 6 characters.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = _isSignUp
          ? await widget.api.signUpWithSupabase(
              email: email,
              password: password,
            )
          : await widget.api.signInWithSupabase(
              email: email,
              password: password,
            );

      if (session.workspaces.isEmpty && _workspaceCtrl.text.trim().isNotEmpty) {
        await widget.api.bootstrapSupabaseWorkspace(
          workspaceName: _workspaceCtrl.text.trim(),
          seedDemo: _seedDemo,
        );
      }

      if (mounted) {
        widget.onAuthenticated();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createWorkspaceOnly() async {
    final name = _workspaceCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a workspace / company name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.bootstrapSupabaseWorkspace(
        workspaceName: name,
        seedDemo: _seedDemo,
      );
      if (mounted) widget.onAuthenticated();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = EisNeumorphicTokens.of(context);
    final isAuthenticated = widget.api.sessionState.isAuthenticated;
    final userEmail = widget.api.sessionState.email ?? '';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: NeumorphicSurface(
            depth: NeumorphicDepth.raised,
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    NeumorphicIconBadge(
                      icon: Icons.verified_user_rounded,
                      color: tokens.accentPrimary,
                      size: 46,
                      iconSize: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAuthenticated
                                ? 'Create Compliance Workspace'
                                : 'Supabase Auth • BIR EIS & CAS',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAuthenticated
                                ? 'Signed in as $userEmail'
                                : 'Connected to ${widget.api.connectionLabel}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (!isAuthenticated) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Sign In'),
                        icon: Icon(Icons.login_rounded),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Create Account'),
                        icon: Icon(Icons.person_add_alt_1_rounded),
                      ),
                    ],
                    selected: {_isSignUp},
                    onSelectionChanged: _busy
                        ? null
                        : (sel) => setState(() {
                              _isSignUp = sel.first;
                              _error = null;
                            }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Work Email',
                      hintText: 'accountant@company.ph',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isSignUp || isAuthenticated) ...[
                  TextField(
                    controller: _workspaceCtrl,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Company / Workspace Name',
                      hintText: 'e.g. Mabuhay Tech PH',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _seedDemo,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _seedDemo = v ?? true),
                    title: const Text(
                      'Seed sample PH taxpayer & demo EIS invoices',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  NeumorphicWell(
                    borderRadius: 12,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: tokens.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : (isAuthenticated ? _createWorkspaceOnly : _submitAuth),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isAuthenticated
                              ? Icons.apartment_rounded
                              : (_isSignUp
                                  ? Icons.rocket_launch_rounded
                                  : Icons.lock_open_rounded),
                        ),
                  label: Text(
                    isAuthenticated
                        ? 'Create Workspace & Continue'
                        : (_isSignUp
                            ? 'Sign Up & Initialize Workspace'
                            : 'Sign In to Workspace'),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : widget.onOpenBackendDialog,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Backend Settings'),
                    ),
                    if (isAuthenticated)
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                await widget.api.signOutSupabase();
                                if (mounted) setState(() {});
                              },
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text('Sign Out'),
                      )
                    else
                      TextButton.icon(
                        onPressed: _busy ? null : widget.onSwitchToLocalEngine,
                        icon: const Icon(Icons.memory_rounded, size: 16),
                        label: const Text('Use Local Engine'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
