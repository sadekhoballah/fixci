import 'missions_models.dart';

class MissionDetailState {
  const MissionDetailState({
    this.isLoading = true,
    this.errorMessage,
    this.mission,
    this.isApplying = false,
    this.isUpdatingStatus = false,
  });

  final bool isLoading;
  final String? errorMessage;
  final MissionDetail? mission;
  final bool isApplying;
  // Owner-only: a withdraw/complete call in flight — disables both buttons
  // together rather than tracking each separately, since only one is ever
  // visible for a given status.
  final bool isUpdatingStatus;

  MissionDetailState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    MissionDetail? mission,
    bool? isApplying,
    bool? isUpdatingStatus,
  }) {
    return MissionDetailState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      mission: mission ?? this.mission,
      isApplying: isApplying ?? this.isApplying,
      isUpdatingStatus: isUpdatingStatus ?? this.isUpdatingStatus,
    );
  }
}
