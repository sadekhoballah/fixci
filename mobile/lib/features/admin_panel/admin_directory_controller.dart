import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_auth_controller.dart';
import 'admin_directory_repository.dart';
import 'admin_directory_state.dart';

const _searchDebounce = Duration(milliseconds: 400);

enum DeleteAccountOutcome { success, activeMission, error }

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

  // Step 2 of the "reset account" flow (see admin_directory_screen.dart).
  // Returns activeMission (rather than setting errorMessage) on a 409 so the
  // screen can offer cancelActiveMissions + retry instead of just showing a
  // dead-end error.
  Future<DeleteAccountOutcome> deleteAccount(
    String userId,
    String? reason,
  ) async {
    if (state.processingIds.contains(userId)) {
      return DeleteAccountOutcome.error;
    }
    state = state.copyWith(
      processingIds: {...state.processingIds, userId},
      clearError: true,
    );
    try {
      await ref
          .read(adminDirectoryRepositoryProvider)
          .deleteAccount(userId, reason);
      state = state.copyWith(
        entries: state.entries.where((e) => e.userId != userId).toList(),
        processingIds: _withoutId(userId),
      );
      return DeleteAccountOutcome.success;
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      final isActiveMission = e.statusCode == 409;
      state = state.copyWith(
        errorMessage: isActiveMission ? null : e.message,
        processingIds: _withoutId(userId),
      );
      return isActiveMission
          ? DeleteAccountOutcome.activeMission
          : DeleteAccountOutcome.error;
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Une erreur est survenue.',
        processingIds: _withoutId(userId),
      );
      return DeleteAccountOutcome.error;
    }
  }

  // Step 1: force-cancels whatever mission the account is a party to.
  // Returns false (and surfaces errorMessage) on failure so the screen
  // knows not to retry the delete.
  Future<bool> cancelActiveMissions(String userId) async {
    try {
      await ref
          .read(adminDirectoryRepositoryProvider)
          .cancelActiveMissions(userId);
      return true;
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Une erreur est survenue.');
      return false;
    }
  }

  Set<String> _withoutId(String id) =>
      state.processingIds.where((existingId) => existingId != id).toSet();

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
