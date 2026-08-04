import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../craftsman_home/craftsman_home_controller.dart';
import '../../craftsman_home/screens/artisan_shell_screen.dart';
import '../onboarding_controller.dart';
import 'payment_checkout_screen.dart';

class TierSelectionScreen extends ConsumerStatefulWidget {
  const TierSelectionScreen({super.key, this.isChangingPlan = false});

  // True when reached from the craftsman's Account tab to change an already
  // active plan, rather than during onboarding. Changes the copy, drops the
  // free tier from the list (downgrading to free isn't a payment — there's
  // no backend endpoint for it), and changes what happens after checkout.
  final bool isChangingPlan;

  @override
  ConsumerState<TierSelectionScreen> createState() =>
      _TierSelectionScreenState();
}

class _TierSelectionScreenState extends ConsumerState<TierSelectionScreen> {
  SubscriptionTier? _selected;
  bool _continuing = false;

  List<SubscriptionTier> get _availableTiers => widget.isChangingPlan
      ? SubscriptionTier.values.where((tier) => tier.isPaid).toList()
      : SubscriptionTier.values;

  // During onboarding the country comes from the phone field the craftsman
  // just filled in; when changing an already-active plan there's no
  // onboarding state, so it comes from their registered account instead
  // (see CraftsmanHomeState.countryCode, populated from GET /craftsmen/me).
  String _countryCode(WidgetRef ref) => widget.isChangingPlan
      ? ref.watch(craftsmanHomeControllerProvider).countryCode
      : ref.watch(onboardingControllerProvider).phoneCountryCode;

  Future<void> _continue(String countryCode) async {
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
      MaterialPageRoute(
        builder: (_) => PaymentCheckoutScreen(
          tier: tier,
          countryCode: countryCode,
          isChangingPlan: widget.isChangingPlan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final countryCode = _countryCode(ref);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isChangingPlan
              ? l10n.changePlanTitle
              : l10n.chooseTierTitle,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chooseTierHeading,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isChangingPlan
                    ? l10n.tierChangeNotice
                    : l10n.tierSelectionNotice,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _availableTiers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tier = _availableTiers[index];
                    return _TierOption(
                      tier: tier,
                      countryCode: countryCode,
                      selected: _selected == tier,
                      onTap: () => setState(() => _selected = tier),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: _continuing ? l10n.loadingButton : l10n.continueButton,
                onPressed: (_selected == null || _continuing)
                    ? null
                    : () => _continue(countryCode),
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
    required this.countryCode,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionTier tier;
  final String countryCode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
                    tier.localizedLabel(l10n),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tier.isPaid
                        ? tier.priceLabel(l10n, countryCode)
                        : l10n.freeLabel,
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
