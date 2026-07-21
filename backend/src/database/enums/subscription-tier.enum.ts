// Kept in sync with mobile/lib/core/models/subscription_tier.dart.
export enum SubscriptionTier {
  FREE = 'free',
  BRONZE = 'bronze',
  SILVER = 'silver',
  GOLD = 'gold',
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
