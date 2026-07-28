import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_auth_controller.dart';
import 'admin_kyc_repository.dart';
import 'admin_kyc_state.dart';

class AdminKycController extends Notifier<AdminKycState> {
  @override
  AdminKycState build() {
    Future.microtask(refresh);
    return const AdminKycState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final entries = await ref
          .read(adminKycRepositoryProvider)
          .getPendingVerifications();
      state = state.copyWith(isLoading: false, entries: entries);
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les demandes en attente.',
      );
    }
  }

  Future<void> approve(String userId) => _resolve(userId, (repo) {
    final role = _roleOf(userId);
    return role == VerificationRole.client
        ? repo.verifyClient(userId)
        : repo.verifyCraftsman(userId);
  });

  Future<void> reject(String userId, String? reason) => _resolve(userId, (
    repo,
  ) {
    final role = _roleOf(userId);
    return role == VerificationRole.client
        ? repo.deactivateClient(userId, reason)
        : repo.deactivateCraftsman(userId, reason);
  });

  VerificationRole _roleOf(String userId) =>
      state.entries.firstWhere((e) => e.userId == userId).role;

  Future<void> _resolve(
    String userId,
    Future<void> Function(AdminKycRepository repository) action,
  ) async {
    if (state.processingUserIds.contains(userId)) return;
    state = state.copyWith(
      processingUserIds: {...state.processingUserIds, userId},
      clearError: true,
    );
    try {
      await action(ref.read(adminKycRepositoryProvider));
      state = state.copyWith(
        entries: state.entries.where((e) => e.userId != userId).toList(),
        processingUserIds: state.processingUserIds
            .where((id) => id != userId)
            .toSet(),
      );
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
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

  // An expired/invalid token surfaces as 401 on whatever request happens to
  // run into it first — bounce back to the login screen right away instead
  // of leaving the admin staring at a generic error message.
  Future<void> _handlePossibleAuthFailure(AdminApiException e) async {
    if (e.statusCode == 401) {
      await ref.read(adminAuthControllerProvider.notifier).logout();
    }
  }
}

final adminKycControllerProvider =
    NotifierProvider<AdminKycController, AdminKycState>(
      AdminKycController.new,
    );
