import '../../core/models/service_category.dart';

enum VerificationRole { craftsman, client }

class PendingVerification {
  const PendingVerification({
    required this.userId,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.serviceCategory,
    required this.experienceDetails,
    required this.createdAt,
  });

  final String userId;
  final VerificationRole role;
  final String phone;
  final String? fullName;
  // Craftsman-only — null for a client entry.
  final ServiceCategory? serviceCategory;
  final String? experienceDetails;
  final DateTime createdAt;
}

class AdminState {
  const AdminState({
    this.entries = const [],
    this.isLoading = true,
    this.errorMessage,
    this.processingUserIds = const {},
  });

  final List<PendingVerification> entries;
  final bool isLoading;
  final String? errorMessage;
  // Which cards currently have an Approve/Reject request in flight — keyed
  // by userId, so each card's buttons disable independently.
  final Set<String> processingUserIds;

  AdminState copyWith({
    List<PendingVerification>? entries,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Set<String>? processingUserIds,
  }) {
    return AdminState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      processingUserIds: processingUserIds ?? this.processingUserIds,
    );
  }
}
