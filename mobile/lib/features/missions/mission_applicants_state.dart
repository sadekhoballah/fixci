import 'missions_models.dart';

class MissionApplicantsState {
  const MissionApplicantsState({
    this.isLoading = true,
    this.errorMessage,
    this.applicants = const [],
    this.processingApplicationIds = const {},
    this.selectedApplicationId,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<MissionApplicant> applicants;
  // Independent per-card busy state while a select action is in flight —
  // mirrors AdminKycState.processingUserIds.
  final Set<String> processingApplicationIds;
  // Set once a selection succeeds, so the screen can show a one-time
  // confirmation and pop back with a result for the detail screen to
  // refresh against.
  final String? selectedApplicationId;

  MissionApplicantsState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<MissionApplicant>? applicants,
    Set<String>? processingApplicationIds,
    String? selectedApplicationId,
  }) {
    return MissionApplicantsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      applicants: applicants ?? this.applicants,
      processingApplicationIds:
          processingApplicationIds ?? this.processingApplicationIds,
      selectedApplicationId: selectedApplicationId ?? this.selectedApplicationId,
    );
  }
}
