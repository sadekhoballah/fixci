import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_auth_controller.dart';
import 'admin_blacklist_repository.dart';
import 'admin_blacklist_state.dart';

class AdminBlacklistController extends Notifier<AdminBlacklistState> {
  @override
  AdminBlacklistState build() {
    Future.microtask(refresh);
    return const AdminBlacklistState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final entries = await ref
          .read(adminBlacklistRepositoryProvider)
          .getEntries();
      state = state.copyWith(isLoading: false, entries: entries);
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger la liste noire.',
      );
    }
  }

  Future<void> addEntry(String phone, String? reason) async {
    try {
      await ref
          .read(adminBlacklistRepositoryProvider)
          .addEntry(phone, reason);
      await refresh();
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Une erreur est survenue.');
    }
  }

  Future<void> removeEntry(String id) async {
    if (state.processingIds.contains(id)) return;
    state = state.copyWith(
      processingIds: {...state.processingIds, id},
      clearError: true,
    );
    try {
      await ref.read(adminBlacklistRepositoryProvider).removeEntry(id);
      state = state.copyWith(
        entries: state.entries.where((e) => e.id != id).toList(),
        processingIds: state.processingIds
            .where((existingId) => existingId != id)
            .toSet(),
      );
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(
        errorMessage: e.message,
        processingIds: state.processingIds
            .where((existingId) => existingId != id)
            .toSet(),
      );
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Une erreur est survenue.',
        processingIds: state.processingIds
            .where((existingId) => existingId != id)
            .toSet(),
      );
    }
  }

  Future<void> _handlePossibleAuthFailure(AdminApiException e) async {
    if (e.statusCode == 401) {
      await ref.read(adminAuthControllerProvider.notifier).logout();
    }
  }
}

final adminBlacklistControllerProvider =
    NotifierProvider<AdminBlacklistController, AdminBlacklistState>(
      AdminBlacklistController.new,
    );
