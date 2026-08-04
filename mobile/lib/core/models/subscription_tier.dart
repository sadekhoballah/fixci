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

  // Lebanon's launch pricing — flat round USD figures rather than a literal
  // CFA/610 conversion, which lands on awkward non-round numbers. Kept in
  // sync with SUBSCRIPTION_TIER_PRICE_USD in the backend's
  // subscription-tier.enum.ts, which is the actual source of truth for what
  // a plan costs (see PaymentsService.subscribe).
  int get priceUsd => switch (this) {
    SubscriptionTier.free => 0,
    SubscriptionTier.bronze => 5,
    SubscriptionTier.silver => 8,
    SubscriptionTier.gold => 16,
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
// replacing it outright since craftsman_header.dart and account_screen.dart
// still read .label directly and aren't migrated yet. Bronze/Silver/Gold
// stay identical across every locale — that's the original French copy's
// own choice (only the free tier's "Débutant" was ever translated), not an
// oversight here.
extension SubscriptionTierLocalization on SubscriptionTier {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    SubscriptionTier.free => l10n.tierFreeLabel,
    SubscriptionTier.bronze => l10n.tierBronzeLabel,
    SubscriptionTier.silver => l10n.tierSilverLabel,
    SubscriptionTier.gold => l10n.tierGoldLabel,
  };

  // Lebanon (LB) pays in USD via Whish; every other launched country pays in
  // CFA via Wave (see PaymentProvider.forCountry below, which the checkout
  // screen uses to pick the matching payment instructions/copy).
  String priceLabel(AppLocalizations l10n, String countryCode) =>
      countryCode == 'LB'
          ? l10n.priceUsdPerMonth(priceUsd)
          : l10n.priceCfaPerMonth(priceCfa);
}

enum PaymentProvider {
  wave,
  whish;

  static PaymentProvider forCountry(String countryCode) =>
      countryCode == 'LB' ? PaymentProvider.whish : PaymentProvider.wave;
}
