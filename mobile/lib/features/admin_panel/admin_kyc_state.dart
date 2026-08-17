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
    required this.licenseVerified,
    required this.createdAt,
  });

  final String userId;
  final VerificationRole role;
  final String phone;
  final String? fullName;
  // Craftsman-only — null for a client entry.
  final ServiceCategory? serviceCategory;
  final String? experienceDetails;
  // Craftsman-only, meaningful only when serviceCategory.requiresDriverLicense
  // is true (taxi/camion) — whether the license half of KYC is done, so the
  // card can show its own preview/status independent of the ID card's.
  final bool licenseVerified;
  final DateTime createdAt;
}

class AdminKycState {
  const AdminKycState({
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

  AdminKycState copyWith({
    List<PendingVerification>? entries,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Set<String>? processingUserIds,
  }) {
    return AdminKycState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      processingUserIds: processingUserIds ?? this.processingUserIds,
    );
  }
}
