import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/session_storage.dart';
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
