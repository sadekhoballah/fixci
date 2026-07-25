import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import 'client_jobs_repository.dart';
import 'client_jobs_state.dart';

const _pageSize = 20;

class ClientJobsController extends Notifier<ClientJobsState> {
  @override
  ClientJobsState build() {
    Future.microtask(refresh);
    return const ClientJobsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref
          .read(clientJobsRepositoryProvider)
          .getRequests(limit: _pageSize, offset: 0);
      state = state.copyWith(
        isLoading: false,
        entries: page.items,
        hasMore: page.hasMore,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Impossible de charger l'historique.",
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await ref
          .read(clientJobsRepositoryProvider)
          .getRequests(limit: _pageSize, offset: state.entries.length);
      state = state.copyWith(
        isLoadingMore: false,
        entries: [...state.entries, ...page.items],
        hasMore: page.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final clientJobsControllerProvider =
    NotifierProvider<ClientJobsController, ClientJobsState>(
      ClientJobsController.new,
    );
