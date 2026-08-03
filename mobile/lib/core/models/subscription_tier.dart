import '../../l10n/app_localizations.dart';

enum SubscriptionTier {
  free,
  bronze,
  silver,
  gold;

  String get label => switch (this) {
    SubscriptionTier.free => 'Débutant',
    SubscriptionTier.bronze => 'Bronze',
    SubscriptionTier.silver => 'Silver',
    SubscriptionTier.gold => 'Gold',
  };

  int get priceCfa => switch (this) {
    SubscriptionTier.free => 0,
    SubscriptionTier.bronze => 3000,
    SubscriptionTier.silver => 5000,
    SubscriptionTier.gold => 10000,
  };

  bool get isPaid => this != SubscriptionTier.free;

  String get wireValue => switch (this) {
    SubscriptionTier.free => 'free',
    SubscriptionTier.bronze => 'bronze',
    SubscriptionTier.silver => 'silver',
    SubscriptionTier.gold => 'gold',
  };
}

// Localized counterpart to .label above — kept separate rather than
// replacing it outright since tier_selection_screen.dart,
// wave_payment_checkout_screen.dart, craftsman_header.dart, and
// account_screen.dart all still read .label directly and aren't migrated
// yet. Bronze/Silver/Gold stay identical across every locale — that's the
// original French copy's own choice (only the free tier's "Débutant" was
// ever translated), not an oversight here.
extension SubscriptionTierLocalization on SubscriptionTier {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    SubscriptionTier.free => l10n.tierFreeLabel,
    SubscriptionTier.bronze => l10n.tierBronzeLabel,
    SubscriptionTier.silver => l10n.tierSilverLabel,
    SubscriptionTier.gold => l10n.tierGoldLabel,
  };
}
