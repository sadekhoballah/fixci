import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/location/location_service.dart' as location_service;
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';
import 'missions_board_state.dart';
import 'missions_repository.dart';

const _pageSize = 20;

// Persistent tab controller (not autoDispose) — mirrors ClientJobsController:
// state survives switching away to another bottom-nav tab and back, rather
// than refetching every time.
class MissionsBoardController extends Notifier<MissionsBoardState> {
  @override
  MissionsBoardState build() {
    // Fired in parallel, not chained — the list must render as soon as the
    // server answers, regardless of how long (or whether) the GPS fix ever
    // resolves. Previously refresh() only ran *after* the position fetch,
    // so a stuck/slow permission request (see location_service.dart) left
    // the board spinning forever instead of just falling back to
    // most-recent-first.
    Future.microtask(refresh);
    Future.microtask(_loadPositionThenRefresh);
    return const MissionsBoardState();
  }

  // Best-effort only — a denied/unavailable position just means the board
  // stays sorted most-recent-first (server-side default), never blocks the
  // list from loading. If a position does resolve, re-run refresh() so the
  // board re-sorts by distance.
  Future<void> _loadPositionThenRefresh() async {
    final position = await location_service.getCurrentPosition();
    if (position == null) return;
    state = state.copyWith(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    await refresh();
  }

  void setCategory(ServiceCategory? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
    refresh();
  }

  // Explicit district — any district the caller wants, not just their own
  // (founder's call). Passing null id resets to the default "my district"
  // behavior (see MissionsBoardState.isDefaultLocationFilter).
  void setDistrict(String? districtId, String? districtName) {
    state = districtId == null
        ? state.copyWith(clearDistrict: true)
        : state.copyWith(
            districtId: districtId,
            districtName: districtName,
            allDistricts: false,
          );
    refresh();
  }

  void setAllDistricts() {
    state = state.copyWith(clearDistrict: true, allDistricts: true);
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref
          .read(missionsRepositoryProvider)
          .browseMissions(
            limit: _pageSize,
            offset: 0,
            latitude: state.latitude,
            longitude: state.longitude,
            category: state.category,
            districtId: state.districtId,
            allDistricts: state.allDistricts,
            // The 5km cap only makes sense for the default "near me" view —
            // once the caller explicitly picked a district (their own
            // re-selected doesn't count, that's still the default), they're
            // deliberately browsing away from their own position.
            maxDistanceKm: state.isDefaultLocationFilter
                ? kDefaultBoardRadiusKm
                : null,
          );
      state = state.copyWith(
        isLoading: false,
        items: page.items,
        hasMore: page.hasMore,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ref.read(l10nProvider).genericErrorMessage,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await ref
          .read(missionsRepositoryProvider)
          .browseMissions(
            limit: _pageSize,
            offset: state.items.length,
            latitude: state.latitude,
            longitude: state.longitude,
            category: state.category,
            districtId: state.districtId,
            allDistricts: state.allDistricts,
            maxDistanceKm: state.isDefaultLocationFilter
                ? kDefaultBoardRadiusKm
                : null,
          );
      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...page.items],
        hasMore: page.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final missionsBoardControllerProvider =
    NotifierProvider<MissionsBoardController, MissionsBoardState>(
      MissionsBoardController.new,
    );
