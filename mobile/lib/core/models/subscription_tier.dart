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
