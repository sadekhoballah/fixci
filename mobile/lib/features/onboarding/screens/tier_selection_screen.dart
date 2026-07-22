import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../craftsman_home/screens/artisan_shell_screen.dart';
import '../onboarding_controller.dart';
import 'wave_payment_checkout_screen.dart';

class TierSelectionScreen extends ConsumerStatefulWidget {
  const TierSelectionScreen({super.key});

  @override
  ConsumerState<TierSelectionScreen> createState() =>
      _TierSelectionScreenState();
}

class _TierSelectionScreenState extends ConsumerState<TierSelectionScreen> {
  SubscriptionTier? _selected;
  bool _continuing = false;

  Future<void> _continue() async {
    final tier = _selected;
    if (tier == null || _continuing) return;

    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.selectTier(tier);

    if (!tier.isPaid) {
      setState(() => _continuing = true);
      await controller.confirmActiveTier();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ArtisanShellScreen()),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WavePaymentCheckoutScreen(tier: tier)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisissez votre formule')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisissez la formule qui vous convient',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous pourrez changer de formule à tout moment.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: SubscriptionTier.values.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tier = SubscriptionTier.values[index];
                    return _TierOption(
                      tier: tier,
                      selected: _selected == tier,
                      onTap: () => setState(() => _selected = tier),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: _continuing ? 'Chargement...' : 'Continuer',
                onPressed: (_selected == null || _continuing)
                    ? null
                    : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierOption extends StatelessWidget {
  const _TierOption({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tier.isPaid ? '${tier.priceCfa} CFA / mois' : 'Gratuit',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
