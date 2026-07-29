class BroadcastHistoryEntry {
  const BroadcastHistoryEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.targetRole,
    required this.targetServiceCategory,
    required this.targetDistrictName,
    required this.waitlistOnly,
    required this.recipientCount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? targetRole;
  final String? targetServiceCategory;
  final String? targetDistrictName;
  final bool waitlistOnly;
  final int recipientCount;
  final DateTime createdAt;
}

class BroadcastSendResult {
  const BroadcastSendResult({
    required this.recipientCount,
    required this.successCount,
    required this.failureCount,
  });

  final int recipientCount;
  final int successCount;
  final int failureCount;
}

class AdminBroadcastState {
  const AdminBroadcastState({
    this.history = const [],
    this.isLoadingHistory = true,
    this.isSending = false,
    this.errorMessage,
    this.lastResult,
  });

  final List<BroadcastHistoryEntry> history;
  final bool isLoadingHistory;
  final bool isSending;
  final String? errorMessage;
  final BroadcastSendResult? lastResult;

  AdminBroadcastState copyWith({
    List<BroadcastHistoryEntry>? history,
    bool? isLoadingHistory,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
    BroadcastSendResult? lastResult,
    bool clearLastResult = false,
  }) {
    return AdminBroadcastState(
      history: history ?? this.history,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
    );
  }
}
