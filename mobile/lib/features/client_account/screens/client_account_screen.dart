import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/session_storage.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/media/id_card_picker.dart';
import '../../../core/media/image_validation.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../onboarding/screens/role_selection_screen.dart';

class _ClientMe {
  const _ClientMe({
    required this.fullName,
    required this.phone,
    required this.idVerified,
    required this.isActive,
    required this.completedMissionsCount,
  });

  final String? fullName;
  final String phone;
  final bool idVerified;
  // False only ever means an admin rejected this account.
  final bool isActive;
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
  bool _isResubmittingIdCard = false;
  String? _resubmitError;
  bool _isDeletingAccount = false;

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://fix-pro.app/privacy/');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
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
          idVerified: response['idVerified'] as bool,
          isActive: response['isActive'] as bool,
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

  // Lets a rejected (isActive: false) client attach a fresh ID photo without
  // going through a whole new registration — mirrors
  // CraftsmanHomeController's resubmitIdCardFromGallery/FromCamera pick→
  // validate→upload sequence, just kept local to this screen's own state
  // instead of a dedicated controller, matching how this screen already
  // manages its data.
  Future<void> _resubmitIdCardFromGallery() =>
      _resubmitIdCard(ref.read(idCardPickerProvider).pickFromGallery);

  Future<void> _resubmitIdCardFromCamera() =>
      _resubmitIdCard(ref.read(idCardPickerProvider).pickFromCamera);

  Future<void> _resubmitIdCard(
    Future<PickedImage?> Function() pick,
  ) async {
    setState(() => _resubmitError = null);
    final PickedImage? image;
    try {
      image = await pick();
    } on IdCardPickerException catch (e) {
      if (mounted) {
        setState(
          () => _resubmitError = e.error.localizedMessage(
            AppLocalizations.of(context)!,
          ),
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(
          () => _resubmitError =
              AppLocalizations.of(context)!.unableToSelectImageMessage,
        );
      }
      return;
    }
    if (image == null) return; // user cancelled the picker

    try {
      await validateIdCardImage(image.bytes);
    } on ImageValidationException catch (e) {
      if (mounted) {
        setState(
          () => _resubmitError = e.error.localizedMessage(
            AppLocalizations.of(context)!,
          ),
        );
      }
      return;
    }

    setState(() {
      _isResubmittingIdCard = true;
      _resubmitError = null;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final uploadResponse = await apiClient.postMultipart(
        '/uploads/id-card',
        'file',
        image.bytes,
        image.filename,
        contentTypeHeader: image.mimeType,
      );
      final storageKey = uploadResponse['storageKey'] as String;
      await apiClient.patch('/clients/me/id-card', {
        'idCardStorageKey': storageKey,
      });
      if (!mounted) return;
      setState(() => _isResubmittingIdCard = false);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isResubmittingIdCard = false;
          _resubmitError = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isResubmittingIdCard = false;
          _resubmitError =
              AppLocalizations.of(context)!.idCardUploadFailedMessage;
        });
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
                  const SizedBox(height: 16),
                  _VerificationStatusCard(
                    idVerified: me.idVerified,
                    isActive: me.isActive,
                    isResubmitting: _isResubmittingIdCard,
                    errorMessage: _resubmitError,
                    onResubmitFromGallery: _resubmitIdCardFromGallery,
                    onResubmitFromCamera: _resubmitIdCardFromCamera,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: _openPrivacyPolicy,
                      child: Text(l10n.privacyPolicyButton),
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

// Mirrors AccountScreen's _VerificationStatusCard (craftsman side) — same
// three states (verified / rejected / pending) derived from idVerified +
// isActive, same colors and copy, so both roles read identically.
class _VerificationStatusCard extends StatelessWidget {
  const _VerificationStatusCard({
    required this.idVerified,
    required this.isActive,
    required this.isResubmitting,
    required this.errorMessage,
    required this.onResubmitFromGallery,
    required this.onResubmitFromCamera,
  });

  final bool idVerified;
  final bool isActive;
  final bool isResubmitting;
  final String? errorMessage;
  final Future<void> Function() onResubmitFromGallery;
  final Future<void> Function() onResubmitFromCamera;

  Future<void> _showSourceSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (idCardCameraSupported)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.takePhotoLabel),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onResubmitFromCamera();
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGalleryLabel),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onResubmitFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Rejected takes priority over "verified" being stale from before a
    // resubmission — isActive: false is the one state that needs the user
    // to actually do something.
    final rejected = !isActive;

    final (bg, fg, icon, title, message) = switch (true) {
      _ when idVerified => (
        const Color(0xFFE0F2E9),
        const Color(0xFF1B8A3B),
        Icons.verified_rounded,
        l10n.identityVerifiedTitle,
        l10n.identityVerifiedMessage,
      ),
      _ when rejected => (
        const Color(0xFFFDE8E8),
        const Color(0xFFC62828),
        Icons.cancel_rounded,
        l10n.requestRejectedTitle,
        l10n.requestRejectedMessage,
      ),
      _ => (
        const Color(0xFFFFF3CD),
        const Color(0xFF7A5B00),
        Icons.pending_rounded,
        l10n.pendingVerificationTitle,
        l10n.pendingVerificationMessage,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(fontSize: 13, color: fg)),
          if (rejected) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isResubmitting ? null : () => _showSourceSheet(context),
                icon: isResubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(l10n.resubmitIdCardButton),
                style: OutlinedButton.styleFrom(foregroundColor: fg),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
              ),
            ],
          ],
        ],
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
