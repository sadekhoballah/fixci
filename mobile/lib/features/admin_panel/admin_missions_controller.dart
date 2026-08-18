import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_auth_controller.dart';
import 'admin_missions_repository.dart';
import 'admin_missions_state.dart';

class AdminMissionsController extends Notifier<AdminMissionsState> {
  @override
  AdminMissionsState build() {
    Future.microtask(refresh);
    return const AdminMissionsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final entries = await ref
          .read(adminMissionsRepositoryProvider)
          .getPendingMissions();
      state = state.copyWith(isLoading: false, entries: entries);
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les missions en attente.',
      );
    }
  }

  Future<void> approve(String missionId) => _resolve(
    missionId,
    (repo) => repo.approveMission(missionId),
  );

  Future<void> reject(String missionId, String? reason) => _resolve(
    missionId,
    (repo) => repo.rejectMission(missionId, reason),
  );

  Future<void> _resolve(
    String missionId,
    Future<void> Function(AdminMissionsRepository repository) action,
  ) async {
    if (state.processingMissionIds.contains(missionId)) return;
    state = state.copyWith(
      processingMissionIds: {...state.processingMissionIds, missionId},
      clearError: true,
    );
    try {
      await action(ref.read(adminMissionsRepositoryProvider));
      state = state.copyWith(
        entries: state.entries.where((e) => e.id != missionId).toList(),
        processingMissionIds: state.processingMissionIds
            .where((id) => id != missionId)
            .toSet(),
      );
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(
        errorMessage: e.message,
        processingMissionIds: state.processingMissionIds
            .where((id) => id != missionId)
            .toSet(),
      );
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Une erreur est survenue.',
        processingMissionIds: state.processingMissionIds
            .where((id) => id != missionId)
            .toSet(),
      );
    }
  }

  // An expired/invalid token surfaces as 401 on whatever request happens to
  // run into it first — bounce back to the login screen right away instead
  // of leaving the admin staring at a generic error message.
  Future<void> _handlePossibleAuthFailure(AdminApiException e) async {
    if (e.statusCode == 401) {
      await ref.read(adminAuthControllerProvider.notifier).logout();
    }
  }
}

final adminMissionsControllerProvider =
    NotifierProvider<AdminMissionsController, AdminMissionsState>(
      AdminMissionsController.new,
    );
