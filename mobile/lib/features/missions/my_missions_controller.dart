import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/network/api_client.dart';
import 'missions_repository.dart';
import 'my_missions_state.dart';

const _pageSize = 20;

// Scoped to the "Mes missions" tab (autoDispose) — a fresh fetch each time
// it's opened rather than a persistent cache, since mission status changes
// server-side (moderation, candidatures, completion) independently of
// anything this screen does.
class MyMissionsController extends Notifier<MyMissionsState> {
  @override
  MyMissionsState build() {
    Future.microtask(refresh);
    return const MyMissionsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref
          .read(missionsRepositoryProvider)
          .getMyMissions(limit: _pageSize, offset: 0);
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
          .getMyMissions(limit: _pageSize, offset: state.items.length);
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

final myMissionsControllerProvider =
    NotifierProvider.autoDispose<MyMissionsController, MyMissionsState>(
      MyMissionsController.new,
    );
