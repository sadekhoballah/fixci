import 'package:geolocator/geolocator.dart';
import '../../core/models/service_category.dart';
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
    this.fullName,
    this.tier = SubscriptionTier.free,
    this.daysRemaining,
    this.isAvailable = false,
    this.isTogglingAvailability = false,
    this.averageRating,
    this.ratingsCount = 0,
    this.stats,
    this.serviceCategory,
    this.locationServiceEnabled = false,
    this.locationPermission = LocationPermission.denied,
    this.idVerified = false,
    this.isActive = true,
    this.isResubmittingIdCard = false,
    this.countryCode = 'CI',
  });

  final bool isLoading;
  final String? errorMessage;
  final String? fullName;
  final SubscriptionTier tier;
  final int? daysRemaining;
  final bool isAvailable;
  final bool isTogglingAvailability;
  final double? averageRating;
  final int ratingsCount;
  final CraftsmanHomeStats? stats;
  final ServiceCategory? serviceCategory;
  final bool locationServiceEnabled;
  final LocationPermission locationPermission;
  final bool idVerified;
  // False only ever means an admin rejected this account.
  final bool isActive;
  final bool isResubmittingIdCard;
  // Drives which subscription currency/provider TierSelectionScreen shows
  // when changing plans from the Account tab (see PaymentProvider.forCountry).
  final String countryCode;

  bool get hasLocationAccess =>
      locationServiceEnabled &&
      (locationPermission == LocationPermission.always ||
          locationPermission == LocationPermission.whileInUse);

  CraftsmanHomeState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? fullName,
    SubscriptionTier? tier,
    int? daysRemaining,
    bool? isAvailable,
    bool? isTogglingAvailability,
    double? averageRating,
    int? ratingsCount,
    CraftsmanHomeStats? stats,
    ServiceCategory? serviceCategory,
    bool? locationServiceEnabled,
    LocationPermission? locationPermission,
    bool? idVerified,
    bool? isActive,
    bool? isResubmittingIdCard,
    String? countryCode,
  }) {
    return CraftsmanHomeState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fullName: fullName ?? this.fullName,
      tier: tier ?? this.tier,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      isAvailable: isAvailable ?? this.isAvailable,
      isTogglingAvailability:
          isTogglingAvailability ?? this.isTogglingAvailability,
      averageRating: averageRating ?? this.averageRating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      stats: stats ?? this.stats,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      locationServiceEnabled:
          locationServiceEnabled ?? this.locationServiceEnabled,
      locationPermission: locationPermission ?? this.locationPermission,
      idVerified: idVerified ?? this.idVerified,
      isActive: isActive ?? this.isActive,
      isResubmittingIdCard:
          isResubmittingIdCard ?? this.isResubmittingIdCard,
      countryCode: countryCode ?? this.countryCode,
    );
  }
}
