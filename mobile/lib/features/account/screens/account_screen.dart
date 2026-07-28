import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/session_storage.dart';
import '../../../core/media/id_card_picker.dart';
import '../../craftsman_home/craftsman_home_controller.dart';
import '../../onboarding/screens/tier_selection_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  String? _phone;

  @override
  void initState() {
    super.initState();
    ref.read(sessionStorageProvider).loadPhone().then((phone) {
      if (mounted) setState(() => _phone = phone);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Reuses the same craftsman-home state the Home tab already loaded (the
    // shell keeps both tabs alive in an IndexedStack) instead of firing a
    // second /craftsmen/me request just to populate this screen.
    final home = ref.watch(craftsmanHomeControllerProvider);
    final controller = ref.read(craftsmanHomeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Compte')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TierSelectionScreen(isChangingPlan: true),
          ),
        ),
        icon: const Icon(Icons.workspace_premium_rounded),
        label: const Text('Changer de forfait'),
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
                      label: home.serviceCategory!.label,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.workspace_premium_rounded,
                    label: home.daysRemaining == null
                        ? home.tier.label
                        : '${home.tier.label} · ${home.daysRemaining} jours restants',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.star_rounded,
                    label: home.averageRating == null
                        ? 'Pas encore de note'
                        : '${home.averageRating!.toStringAsFixed(1)} / 5 (${home.ratingsCount} avis)',
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (idCardCameraSupported)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onResubmitFromCamera();
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
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
    // Rejected takes priority over "verified" being stale from before a
    // resubmission — isActive: false is the one state that needs the user
    // to actually do something.
    final rejected = !isActive;

    final (bg, fg, icon, title, message) = switch (true) {
      _ when idVerified => (
        const Color(0xFFE0F2E9),
        const Color(0xFF1B8A3B),
        Icons.verified_rounded,
        'Identité vérifiée',
        'Votre pièce d\'identité a été validée.',
      ),
      _ when rejected => (
        const Color(0xFFFDE8E8),
        const Color(0xFFC62828),
        Icons.cancel_rounded,
        'Demande rejetée',
        'Votre demande a été rejetée, possiblement à cause d\'informations '
            'incorrectes (photo illisible, document invalide...). Vous '
            'pouvez soumettre une nouvelle pièce d\'identité.',
      ),
      _ => (
        const Color(0xFFFFF3CD),
        const Color(0xFF7A5B00),
        Icons.pending_rounded,
        'En attente de vérification',
        'Votre pièce d\'identité est en cours d\'examen par notre équipe.',
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
                label: const Text('Soumettre une nouvelle pièce d\'identité'),
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
