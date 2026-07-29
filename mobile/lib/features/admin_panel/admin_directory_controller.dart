import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_auth_controller.dart';
import 'admin_directory_repository.dart';
import 'admin_directory_state.dart';

const _searchDebounce = Duration(milliseconds: 400);

class AdminDirectoryController extends Notifier<AdminDirectoryState> {
  Timer? _debounceTimer;

  @override
  AdminDirectoryState build() {
    Future.microtask(refresh);
    ref.onDispose(() => _debounceTimer?.cancel());
    return const AdminDirectoryState();
  }

  void setTab(DirectoryTab tab) {
    if (tab == state.tab) return;
    state = state.copyWith(tab: tab, clearCategory: true, search: '');
    refresh();
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_searchDebounce, refresh);
  }

  void setCategory(String? category) {
    state = state.copyWith(
      category: category,
      clearCategory: category == null,
    );
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(adminDirectoryRepositoryProvider);
      final entries = state.tab == DirectoryTab.clients
          ? await repository.getClients(search: state.search)
          : await repository.getCraftsmen(
              search: state.search,
              category: state.category,
            );
      state = state.copyWith(isLoading: false, entries: entries);
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Impossible de charger l'annuaire.",
      );
    }
  }

  Future<void> _handlePossibleAuthFailure(AdminApiException e) async {
    if (e.statusCode == 401) {
      await ref.read(adminAuthControllerProvider.notifier).logout();
    }
  }
}

final adminDirectoryControllerProvider =
    NotifierProvider<AdminDirectoryController, AdminDirectoryState>(
      AdminDirectoryController.new,
    );
