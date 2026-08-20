// A pending user-to-user report, as returned by GET /admin/reports — mirrors
// AdminPendingMission's shape for the missions moderation queue, one entry
// per report awaiting dismiss/warn/deactivate.
class AdminPendingReport {
  const AdminPendingReport({
    required this.id,
    required this.reporterId,
    required this.reporterFullName,
    required this.reporterPhone,
    required this.reportedUserId,
    required this.reportedUserFullName,
    required this.reportedUserPhone,
    required this.reason,
    required this.message,
    required this.contextType,
    required this.contextId,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final String? reporterFullName;
  final String? reporterPhone;
  final String reportedUserId;
  final String? reportedUserFullName;
  final String? reportedUserPhone;
  final String reason;
  final String? message;
  final String? contextType;
  final String? contextId;
  final DateTime createdAt;
}

class AdminReportsState {
  const AdminReportsState({
    this.entries = const [],
    this.isLoading = true,
    this.errorMessage,
    this.processingReportIds = const {},
  });

  final List<AdminPendingReport> entries;
  final bool isLoading;
  final String? errorMessage;
  // Which cards currently have a dismiss/warn/deactivate request in flight —
  // keyed by report id, mirrors AdminMissionsState.processingMissionIds.
  final Set<String> processingReportIds;

  AdminReportsState copyWith({
    List<AdminPendingReport>? entries,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Set<String>? processingReportIds,
  }) {
    return AdminReportsState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      processingReportIds: processingReportIds ?? this.processingReportIds,
    );
  }
}
