import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_auth_controller.dart';
import 'admin_broadcast_repository.dart';
import 'admin_broadcast_state.dart';

class AdminBroadcastController extends Notifier<AdminBroadcastState> {
  @override
  AdminBroadcastState build() {
    Future.microtask(refreshHistory);
    return const AdminBroadcastState();
  }

  Future<void> refreshHistory() async {
    state = state.copyWith(isLoadingHistory: true, clearError: true);
    try {
      final history = await ref
          .read(adminBroadcastRepositoryProvider)
          .getHistory();
      state = state.copyWith(isLoadingHistory: false, history: history);
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(isLoadingHistory: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoadingHistory: false,
        errorMessage: "Impossible de charger l'historique.",
      );
    }
  }

  Future<void> send({
    required String title,
    required String body,
    String? role,
    String? serviceCategory,
    String? districtId,
    bool waitlistOnly = false,
  }) async {
    state = state.copyWith(
      isSending: true,
      clearError: true,
      clearLastResult: true,
    );
    try {
      final result = await ref
          .read(adminBroadcastRepositoryProvider)
          .send(
            title: title,
            body: body,
            role: role,
            serviceCategory: serviceCategory,
            districtId: districtId,
            waitlistOnly: waitlistOnly,
          );
      state = state.copyWith(isSending: false, lastResult: result);
      await refreshHistory();
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(isSending: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Une erreur est survenue.',
      );
    }
  }

  Future<void> _handlePossibleAuthFailure(AdminApiException e) async {
    if (e.statusCode == 401) {
      await ref.read(adminAuthControllerProvider.notifier).logout();
    }
  }
}

final adminBroadcastControllerProvider =
    NotifierProvider<AdminBroadcastController, AdminBroadcastState>(
      AdminBroadcastController.new,
    );
