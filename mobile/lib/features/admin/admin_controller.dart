import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import 'admin_repository.dart';
import 'admin_state.dart';

class AdminController extends Notifier<AdminState> {
  @override
  AdminState build() {
    Future.microtask(refresh);
    return const AdminState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final entries = await ref
          .read(adminRepositoryProvider)
          .getPendingVerifications();
      state = state.copyWith(isLoading: false, entries: entries);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les demandes en attente.',
      );
    }
  }

  Future<void> approve(String userId) =>
      _resolve(userId, (repo) => repo.verifyCraftsman(userId));

  Future<void> reject(String userId) =>
      _resolve(userId, (repo) => repo.deactivateCraftsman(userId));

  Future<void> _resolve(
    String userId,
    Future<void> Function(AdminRepository repository) action,
  ) async {
    if (state.processingUserIds.contains(userId)) return;
    state = state.copyWith(
      processingUserIds: {...state.processingUserIds, userId},
      clearError: true,
    );
    try {
      await action(ref.read(adminRepositoryProvider));
      state = state.copyWith(
        entries: state.entries.where((e) => e.userId != userId).toList(),
        processingUserIds: state.processingUserIds
            .where((id) => id != userId)
            .toSet(),
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        errorMessage: e.message,
        processingUserIds: state.processingUserIds
            .where((id) => id != userId)
            .toSet(),
      );
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Une erreur est survenue.',
        processingUserIds: state.processingUserIds
            .where((id) => id != userId)
            .toSet(),
      );
    }
  }
}

final adminControllerProvider = NotifierProvider<AdminController, AdminState>(
  AdminController.new,
);
