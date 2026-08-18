import 'missions_models.dart';

class MissionsBoardState {
  const MissionsBoardState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.latitude,
    this.longitude,
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

  MissionsBoardState copyWith({
    List<MissionSummary>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    double? latitude,
    double? longitude,
  }) {
    return MissionsBoardState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
