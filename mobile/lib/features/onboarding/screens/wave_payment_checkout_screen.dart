import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../craftsman_home/screens/craftsman_dashboard_screen.dart';
import '../onboarding_controller.dart';

// Placeholder checkout: there's no real Wave API integration yet, so the
// artisan pays via the Wave app outside FixCi and manually confirms here —
// matches the "manual confirmation on LAN" approach for now.
class WavePaymentCheckoutScreen extends ConsumerStatefulWidget {
  const WavePaymentCheckoutScreen({super.key, required this.tier});

  final SubscriptionTier tier;

  @override
  ConsumerState<WavePaymentCheckoutScreen> createState() =>
      _WavePaymentCheckoutScreenState();
}

class _WavePaymentCheckoutScreenState
    extends ConsumerState<WavePaymentCheckoutScreen> {
  bool _confirming = false;

  Future<void> _confirmPayment() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    await ref
        .read(onboardingControllerProvider.notifier)
        .confirmActiveTier();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CraftsmanDashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement Wave')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Formule ${widget.tier.label}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.tier.priceCfa} CFA / mois',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Ouvrez l'application Wave, envoyez le montant ci-dessus, "
                  'puis confirmez votre paiement ci-dessous.',
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: _confirming
                    ? 'Confirmation...'
                    : "J'ai effectué le paiement",
                onPressed: _confirming ? null : _confirmPayment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
