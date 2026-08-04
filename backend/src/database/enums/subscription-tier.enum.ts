// Kept in sync with mobile/lib/core/models/subscription_tier.dart.
export enum SubscriptionTier {
  FREE = 'free',
  BRONZE = 'bronze',
  SILVER = 'silver',
  GOLD = 'gold',
}

export enum Currency {
  CFA = 'CFA',
  USD = 'USD',
}

// Kept in sync with SubscriptionTier.priceCfa in the same Dart file — the
// backend is the source of truth for what a plan actually costs, since the
// client's price is never trusted for the charge amount.
export const SUBSCRIPTION_TIER_PRICE_CFA: Record<SubscriptionTier, number> = {
  [SubscriptionTier.FREE]: 0,
  [SubscriptionTier.BRONZE]: 3000,
  [SubscriptionTier.SILVER]: 5000,
  [SubscriptionTier.GOLD]: 10000,
};

// Lebanon's launch pricing, adopted as flat round USD figures rather than a
// literal CFA/610 conversion (which lands on awkward non-round numbers).
export const SUBSCRIPTION_TIER_PRICE_USD: Record<SubscriptionTier, number> = {
  [SubscriptionTier.FREE]: 0,
  [SubscriptionTier.BRONZE]: 5,
  [SubscriptionTier.SILVER]: 8,
  [SubscriptionTier.GOLD]: 16,
};

// Keyed by District.countryCode. Every launched country must appear here —
// getSubscriptionPrice throws for anything else, the same way an unlaunched
// country is refused registration in the first place (see
// OnboardingState.isCountryLaunched on the mobile side).
export const CURRENCY_BY_COUNTRY: Record<string, Currency> = {
  CI: Currency.CFA,
  LB: Currency.USD,
};

export function getSubscriptionPrice(
  tier: SubscriptionTier,
  countryCode: string,
): { amount: number; currency: Currency } {
  const currency = CURRENCY_BY_COUNTRY[countryCode];
  if (!currency) {
    throw new Error(`No subscription pricing configured for ${countryCode}`);
  }
  const amount =
    currency === Currency.USD
      ? SUBSCRIPTION_TIER_PRICE_USD[tier]
      : SUBSCRIPTION_TIER_PRICE_CFA[tier];
  return { amount, currency };
}
