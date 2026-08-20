import 'safety_repository.dart';

class BlockedUsersState {
  const BlockedUsersState({
    this.items = const [],
    this.isLoading = true,
    this.errorMessage,
    this.processingUserIds = const {},
  });

  final List<BlockedUser> items;
  final bool isLoading;
  final String? errorMessage;
  // Which rows currently have an "Unblock" request in flight — keyed by
  // userId, mirrors AdminMissionsState.processingMissionIds.
  final Set<String> processingUserIds;

  BlockedUsersState copyWith({
    List<BlockedUser>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Set<String>? processingUserIds,
  }) {
    return BlockedUsersState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      processingUserIds: processingUserIds ?? this.processingUserIds,
    );
  }
}
