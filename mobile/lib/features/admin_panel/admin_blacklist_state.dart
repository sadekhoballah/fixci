class BlacklistedPhone {
  const BlacklistedPhone({
    required this.id,
    required this.phone,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String phone;
  final String? reason;
  final DateTime createdAt;
}

class AdminBlacklistState {
  const AdminBlacklistState({
    this.entries = const [],
    this.isLoading = true,
    this.errorMessage,
    this.processingIds = const {},
  });

  final List<BlacklistedPhone> entries;
  final bool isLoading;
  final String? errorMessage;
  // Which rows currently have a remove request in flight.
  final Set<String> processingIds;

  AdminBlacklistState copyWith({
    List<BlacklistedPhone>? entries,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Set<String>? processingIds,
  }) {
    return AdminBlacklistState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      processingIds: processingIds ?? this.processingIds,
    );
  }
}
