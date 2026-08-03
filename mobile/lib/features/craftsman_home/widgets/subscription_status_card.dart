import 'package:flutter/material.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../l10n/app_localizations.dart';

class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({
    super.key,
    required this.tier,
    required this.daysRemaining,
  });

  final SubscriptionTier tier;
  final int? daysRemaining;

  (Color, Color) _colorsFor(SubscriptionTier tier) => switch (tier) {
    SubscriptionTier.gold => (const Color(0xFFFFD700), const Color(0xFF7A5B00)),
    SubscriptionTier.silver => (
      const Color(0xFFC0C0C0),
      const Color(0xFF4A4A4A),
    ),
    SubscriptionTier.bronze => (
      const Color(0xFFCD7F32),
      const Color(0xFF5A3A16),
    ),
    SubscriptionTier.free => (const Color(0xFFE0E0E0), const Color(0xFF757575)),
  };

  @override
  Widget build(BuildContext context) {
    final (badgeColor, iconColor) = _colorsFor(tier);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
            child: Icon(
              tier.isPaid ? Icons.workspace_premium : Icons.circle_outlined,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tierPlanLabel(tier.localizedLabel(l10n)),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tier.isPaid
                      ? (daysRemaining != null
                            ? l10n.daysRemainingLabel(daysRemaining!)
                            : l10n.activeSubscriptionLabel)
                      : l10n.upgradeForVisibilityMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
