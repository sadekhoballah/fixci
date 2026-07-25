import '../../core/models/service_category.dart';

enum RequestHistoryStatus {
  pending,
  assigned,
  inProgress,
  awaitingConfirmation,
  completed,
  cancelled,
  expired,
}

RequestHistoryStatus parseRequestHistoryStatus(String wireValue) =>
    switch (wireValue) {
      'assigned' => RequestHistoryStatus.assigned,
      'in_progress' => RequestHistoryStatus.inProgress,
      'awaiting_client_confirmation' => RequestHistoryStatus.awaitingConfirmation,
      'completed' => RequestHistoryStatus.completed,
      'cancelled' => RequestHistoryStatus.cancelled,
      'expired' => RequestHistoryStatus.expired,
      _ => RequestHistoryStatus.pending,
    };

class RequestHistoryEntry {
  const RequestHistoryEntry({
    required this.requestId,
    required this.serviceCategory,
    required this.status,
    required this.craftsmanFullName,
    required this.createdAt,
    required this.ratingStars,
  });

  final String requestId;
  final ServiceCategory serviceCategory;
  final RequestHistoryStatus status;
  final String? craftsmanFullName;
  final DateTime createdAt;
  final int? ratingStars;
}

class ClientJobsState {
  const ClientJobsState({
    this.entries = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
  });

  final List<RequestHistoryEntry> entries;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  ClientJobsState copyWith({
    List<RequestHistoryEntry>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ClientJobsState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
