import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_auth_controller.dart';
import 'admin_history_repository.dart';
import 'admin_history_state.dart';

const _pageSize = 50;
const _maxPageSize = 200;
const _searchDebounce = Duration(milliseconds: 400);
const _liveRefreshInterval = Duration(seconds: 30);

// Shared paging / filtering / refresh logic for the two read-only history
// tabs. Subclasses only say how to fetch a page for the current filters.
abstract class _AdminHistoryController<T>
    extends Notifier<AdminHistoryState<T>> {
  Timer? _debounceTimer;
  Timer? _liveTimer;
  // Bumped on every fetch so a slow response for stale filters can't
  // overwrite the result of a newer one.
  int _generation = 0;

  Duration? get liveRefreshInterval => null;

  Future<HistoryPage<T>> fetchPage(
    AdminHistoryRepository repository, {
    required int limit,
    required int offset,
  });

  @override
  AdminHistoryState<T> build() {
    Future.microtask(refresh);
    final interval = liveRefreshInterval;
    if (interval != null) {
      _liveTimer = Timer.periodic(interval, (_) => _silentRefresh());
    }
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _liveTimer?.cancel();
    });
    return AdminHistoryState<T>();
  }

  void setStatus(String? status) {
    if (status == state.status) return;
    state = state.copyWith(status: status, clearStatus: status == null);
    refresh();
  }

  void setDate(DateTime? date) {
    state = state.copyWith(date: date, clearDate: date == null);
    refresh();
  }

  void setSearch(String value) => _debounced(state.copyWith(search: value));

  void setClient(String value) => _debounced(state.copyWith(client: value));

  void setArtisan(String value) => _debounced(state.copyWith(artisan: value));

  void _debounced(AdminHistoryState<T> next) {
    state = next;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_searchDebounce, refresh);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _load(limit: _pageSize, offset: 0, append: false);
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    await _load(limit: _pageSize, offset: state.items.length, append: true);
  }

  // Periodic tick: reload what's already on screen without a spinner.
  Future<void> _silentRefresh() async {
    if (state.isLoading || state.isLoadingMore) return;
    final limit = min(max(state.items.length, _pageSize), _maxPageSize);
    await _load(limit: limit, offset: 0, append: false);
  }

  Future<void> _load({
    required int limit,
    required int offset,
    required bool append,
  }) async {
    final generation = ++_generation;
    try {
      final page = await fetchPage(
        ref.read(adminHistoryRepositoryProvider),
        limit: limit,
        offset: offset,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
        items: append ? [...state.items, ...page.items] : page.items,
        total: page.total,
        byStatus: page.byStatus,
      );
    } on AdminApiException catch (e) {
      if (generation != _generation) return;
      if (e.statusCode == 401) {
        await ref.read(adminAuthControllerProvider.notifier).logout();
      }
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: e.message,
      );
    } catch (_) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: 'Impossible de charger les données.',
      );
    }
  }
}

class AdminMissionHistoryController
    extends _AdminHistoryController<MissionHistoryItem> {
  @override
  Future<HistoryPage<MissionHistoryItem>> fetchPage(
    AdminHistoryRepository repository, {
    required int limit,
    required int offset,
  }) {
    return repository.getMissionHistory(
      status: state.status,
      date: state.date,
      search: state.search,
      limit: limit,
      offset: offset,
    );
  }
}

class AdminRequestHistoryController
    extends _AdminHistoryController<RequestHistoryItem> {
  @override
  Duration? get liveRefreshInterval => _liveRefreshInterval;

  @override
  Future<HistoryPage<RequestHistoryItem>> fetchPage(
    AdminHistoryRepository repository, {
    required int limit,
    required int offset,
  }) {
    return repository.getRequestHistory(
      status: state.status,
      date: state.date,
      client: state.client,
      artisan: state.artisan,
      limit: limit,
      offset: offset,
    );
  }
}

final adminMissionHistoryControllerProvider =
    NotifierProvider<
      AdminMissionHistoryController,
      AdminHistoryState<MissionHistoryItem>
    >(AdminMissionHistoryController.new);

final adminRequestHistoryControllerProvider =
    NotifierProvider<
      AdminRequestHistoryController,
      AdminHistoryState<RequestHistoryItem>
    >(AdminRequestHistoryController.new);
