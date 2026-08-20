import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/network/api_client.dart';
import 'blocked_users_state.dart';
import 'safety_repository.dart';

// Scoped to BlockedUsersScreen (autoDispose) — a fresh fetch each time it's
// opened, same rationale as MyMissionsController: nothing on this screen
// itself changes the underlying data enough to justify a persistent cache.
class BlockedUsersController extends Notifier<BlockedUsersState> {
  @override
  BlockedUsersState build() {
    Future.microtask(refresh);
    return const BlockedUsersState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await ref.read(safetyRepositoryProvider).getBlockedUsers();
      state = state.copyWith(isLoading: false, items: items);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ref.read(l10nProvider).genericErrorMessage,
      );
    }
  }

  Future<void> unblock(String userId) async {
    if (state.processingUserIds.contains(userId)) return;
    state = state.copyWith(
      processingUserIds: {...state.processingUserIds, userId},
      clearError: true,
    );
    try {
      await ref.read(safetyRepositoryProvider).unblockUser(userId);
      state = state.copyWith(
        items: state.items.where((item) => item.userId != userId).toList(),
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
        errorMessage: ref.read(l10nProvider).genericErrorMessage,
        processingUserIds: state.processingUserIds
            .where((id) => id != userId)
            .toSet(),
      );
    }
  }
}

final blockedUsersControllerProvider =
    NotifierProvider.autoDispose<BlockedUsersController, BlockedUsersState>(
      BlockedUsersController.new,
    );
