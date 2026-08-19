import '../../core/models/service_category.dart';
import 'missions_models.dart';

// Default hard radius cap for the "near me" load — see
// MissionsBoardController.refresh. Matches the backend's own maxDistanceKm
// contract (BrowseMissionsQueryDto), kept here as the single source of
// truth for the value rather than a magic 5 sprinkled at each call site.
const kDefaultBoardRadiusKm = 5;

class MissionsBoardState {
  const MissionsBoardState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.latitude,
    this.longitude,
    this.category,
    this.districtId,
    this.districtName,
    this.allDistricts = false,
  });

  final List<MissionSummary> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  // Best-effort caller position, used to sort the board by distance — null
  // until the GPS fix resolves (or silently fails), same "never block on
  // this" contract as location_service.getCurrentPosition itself. When
  // null, the backend falls back to most-recent-first (see
  // MissionsService.browseMissions).
  final double? latitude;
  final double? longitude;
  // Trade filter — null means every category.
  final ServiceCategory? category;
  // Location filter. Both districtId and allDistricts null/false means "use
  // my own district" (the backend's own default when neither is sent — see
  // BrowseMissionsQueryDto) — the board never needs to know the caller's
  // district id itself just to show it on first load. districtName is
  // purely for the filter bar's label once the caller explicitly picks a
  // district; it stays null in the default state.
  final String? districtId;
  final String? districtName;
  final bool allDistricts;

  // Only the default "my district" state applies the hard radius cap — see
  // MissionsBoardController.refresh for why picking any explicit district
  // (including "all districts") drops it.
  bool get isDefaultLocationFilter => districtId == null && !allDistricts;

  MissionsBoardState copyWith({
    List<MissionSummary>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    double? latitude,
    double? longitude,
    ServiceCategory? category,
    bool clearCategory = false,
    String? districtId,
    String? districtName,
    bool clearDistrict = false,
    bool? allDistricts,
  }) {
    return MissionsBoardState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: clearCategory ? null : (category ?? this.category),
      districtId: clearDistrict ? null : (districtId ?? this.districtId),
      districtName: clearDistrict
          ? null
          : (districtName ?? this.districtName),
      // An explicit allDistricts value always wins, even alongside
      // clearDistrict (see MissionsBoardController.setAllDistricts, which
      // needs both: drop any picked districtId AND turn allDistricts on in
      // the same update).
      allDistricts: allDistricts ?? (clearDistrict ? false : this.allDistricts),
    );
  }
}
