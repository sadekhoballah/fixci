import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/location/location_service.dart' as location_service;
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
    Future.microtask(_loadPositionThenRefresh);
    return const MissionsBoardState();
  }

  // Best-effort only — a denied/unavailable position just means the board
  // falls back to most-recent-first server-side, never blocks the list from
  // loading.
  Future<void> _loadPositionThenRefresh() async {
    final position = await location_service.getCurrentPosition();
    if (position != null) {
      state = state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
    await refresh();
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
