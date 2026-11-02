import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/session_storage.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/screens/role_selection_screen.dart';
import '../../safety/screens/blocked_users_screen.dart';

class _ClientMe {
  const _ClientMe({
    required this.fullName,
    required this.phone,
    required this.completedMissionsCount,
  });

  final String? fullName;
  final String phone;
  final int completedMissionsCount;
}

class ClientAccountScreen extends ConsumerStatefulWidget {
  const ClientAccountScreen({super.key});

  @override
  ConsumerState<ClientAccountScreen> createState() => _ClientAccountScreenState();
}

class _ClientAccountScreenState extends ConsumerState<ClientAccountScreen> {
  _ClientMe? _me;
  String? _errorMessage;
  bool _isDeletingAccount = false;

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://fix-pro.app/privacy/');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openTermsOfService() async {
    final uri = Uri.parse('https://fix-pro.app/terms/');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openBlockedUsers() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BlockedUsersScreen()));
  }

  Future<void> _confirmAndDeleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: Text(l10n.clientDeleteAccountConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.deletePermanentlyButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await ref.read(apiClientProvider).delete('/users/me');
      await ref.read(sessionStorageProvider).clearSession();
      await ref.read(tokenStorageProvider).clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deleteAccountFailedMessage)),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ref.read(apiClientProvider).get('/clients/me');
      if (!mounted) return;
      setState(() {
        _me = _ClientMe(
          fullName: response['fullName'] as String?,
          phone: response['phone'] as String,
          completedMissionsCount: response['completedMissionsCount'] as int,
        );
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              AppLocalizations.of(context)!.unableToLoadAccountMessage,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final me = _me;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTab)),
      body: SafeArea(
        child: me == null
            ? Center(
                child: Text(
                  _errorMessage ?? '',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.fullName ?? '—',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(
                          icon: Icons.phone_iphone_rounded,
                          label: me.phone,
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.task_alt_rounded,
                          label: l10n.completedMissionsCount(
                            me.completedMissionsCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: _openPrivacyPolicy,
                      child: Text(l10n.privacyPolicyButton),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _openTermsOfService,
                      child: Text(l10n.termsOfServiceButton),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _openBlockedUsers,
                      child: Text(l10n.blockedUsersScreenTitle),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isDeletingAccount ? null : _confirmAndDeleteAccount,
                    icon: _isDeletingAccount
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(l10n.deleteMyAccountButton),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
