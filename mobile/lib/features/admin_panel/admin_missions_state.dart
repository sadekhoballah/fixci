import '../../core/models/service_category.dart';

// A pending Missions/Freelance board post, as returned by
// GET /admin/missions/pending — mirrors PendingVerification's shape for the
// KYC queue (see admin_kyc_state.dart), one entry per mission awaiting
// approve/reject.
class AdminPendingMission {
  const AdminPendingMission({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.locationAddress,
    required this.photoStorageKeys,
    required this.posterFullName,
    required this.posterPhone,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  // Nullable — a mission doesn't have to fit one of the fixed trades
  // (OTHER_TRADE work), same as Mission.category on the backend.
  final ServiceCategory? category;
  final String locationAddress;
  final List<String> photoStorageKeys;
  final String? posterFullName;
  final String? posterPhone;
  final DateTime createdAt;
}

class AdminMissionsState {
  const AdminMissionsState({
    this.entries = const [],
    this.isLoading = true,
    this.errorMessage,
    this.processingMissionIds = const {},
  });

  final List<AdminPendingMission> entries;
  final bool isLoading;
  final String? errorMessage;
  // Which cards currently have an Approve/Reject request in flight — keyed
  // by mission id, so each card's buttons disable independently.
  final Set<String> processingMissionIds;

  AdminMissionsState copyWith({
    List<AdminPendingMission>? entries,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Set<String>? processingMissionIds,
  }) {
    return AdminMissionsState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      processingMissionIds: processingMissionIds ?? this.processingMissionIds,
    );
  }
}
