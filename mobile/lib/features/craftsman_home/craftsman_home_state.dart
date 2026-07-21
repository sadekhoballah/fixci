import '../../core/models/subscription_tier.dart';

class CraftsmanHomeStats {
  const CraftsmanHomeStats({
    required this.jobsDoneToday,
    required this.jobsAssignedToday,
    required this.avgResponseSeconds,
  });

  final int jobsDoneToday;
  final int jobsAssignedToday;
  final int? avgResponseSeconds;
}

class CraftsmanHomeState {
  const CraftsmanHomeState({
    this.isLoading = true,
    this.errorMessage,
    this.tier = SubscriptionTier.free,
    this.daysRemaining,
    this.isAvailable = false,
    this.isTogglingAvailability = false,
    this.averageRating,
    this.ratingsCount = 0,
    this.stats,
  });

  final bool isLoading;
  final String? errorMessage;
  final SubscriptionTier tier;
  final int? daysRemaining;
  final bool isAvailable;
  final bool isTogglingAvailability;
  final double? averageRating;
  final int ratingsCount;
  final CraftsmanHomeStats? stats;

  CraftsmanHomeState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    SubscriptionTier? tier,
    int? daysRemaining,
    bool? isAvailable,
    bool? isTogglingAvailability,
    double? averageRating,
    int? ratingsCount,
    CraftsmanHomeStats? stats,
  }) {
    return CraftsmanHomeState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      tier: tier ?? this.tier,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      isAvailable: isAvailable ?? this.isAvailable,
      isTogglingAvailability:
          isTogglingAvailability ?? this.isTogglingAvailability,
      averageRating: averageRating ?? this.averageRating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      stats: stats ?? this.stats,
    );
  }
}
