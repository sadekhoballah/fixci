import '../../core/models/service_category.dart';

enum JobHistoryStatus { assigned, inProgress, completed, cancelled, expired }

JobHistoryStatus parseJobHistoryStatus(String wireValue) => switch (wireValue) {
  'in_progress' => JobHistoryStatus.inProgress,
  'completed' => JobHistoryStatus.completed,
  'cancelled' => JobHistoryStatus.cancelled,
  'expired' => JobHistoryStatus.expired,
  _ => JobHistoryStatus.assigned,
};

class JobHistoryEntry {
  const JobHistoryEntry({
    required this.requestId,
    required this.serviceCategory,
    required this.status,
    required this.clientFullName,
    required this.createdAt,
    required this.ratingStars,
  });

  final String requestId;
  final ServiceCategory serviceCategory;
  final JobHistoryStatus status;
  final String? clientFullName;
  final DateTime createdAt;
  final int? ratingStars;
}

class CraftsmanJobsState {
  const CraftsmanJobsState({
    this.entries = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
  });

  final List<JobHistoryEntry> entries;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  CraftsmanJobsState copyWith({
    List<JobHistoryEntry>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CraftsmanJobsState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
