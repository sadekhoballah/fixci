import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/session_storage.dart';
import '../../../core/media/id_card_picker.dart';
import '../../../core/models/service_category.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../core/network/api_client.dart';
import '../../../core/platform/firebase_support.dart';
import '../../../l10n/app_localizations.dart';
import '../../craftsman_home/craftsman_home_controller.dart';
import '../../onboarding/screens/role_selection_screen.dart';
import '../../onboarding/screens/tier_selection_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? _phone;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    ref.read(sessionStorageProvider).loadPhone().then((phone) {
      if (mounted) setState(() => _phone = phone);
    });
  }

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
        content: Text(l10n.deleteAccountConfirmContent),
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
      if (isFirebaseSupportedPlatform && FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // Reuses the same craftsman-home state the Home tab already loaded (the
    // shell keeps both tabs alive in an IndexedStack) instead of firing a
    // second /craftsmen/me request just to populate this screen.
    final home = ref.watch(craftsmanHomeControllerProvider);
    final controller = ref.read(craftsmanHomeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTab)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TierSelectionScreen(isChangingPlan: true),
          ),
        ),
        icon: const Icon(Icons.workspace_premium_rounded),
        label: Text(l10n.changePlanTitle),
      ),
      body: SafeArea(
        child: ListView(
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
                    home.fullName ?? '—',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.phone_iphone_rounded,
                    label: _phone ?? '—',
                  ),
                  if (home.serviceCategory != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: home.serviceCategory!.icon,
                      label: home.serviceCategory!.localizedLabel(l10n),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.workspace_premium_rounded,
                    label: home.daysRemaining == null
                        ? home.tier.localizedLabel(l10n)
                        : l10n.tierWithDaysRemaining(
                            home.tier.localizedLabel(l10n),
                            home.daysRemaining!,
                          ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.star_rounded,
                    label: home.averageRating == null
                        ? l10n.noRatingYetLabel
                        : l10n.ratingOutOfFive(
                            home.averageRating!.toStringAsFixed(1),
                            home.ratingsCount,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _VerificationStatusCard(
              idVerified: home.idVerified,
              isActive: home.isActive,
              isResubmitting: home.isResubmittingIdCard,
              errorMessage: home.errorMessage,
              onResubmitFromGallery: controller.resubmitIdCardFromGallery,
              onResubmitFromCamera: controller.resubmitIdCardFromCamera,
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
