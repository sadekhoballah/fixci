import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/network/api_client.dart';
import 'mission_applicants_state.dart';
import 'missions_repository.dart';

// Scoped to the applicants screen (autoDispose) — a fresh load each time
// it's reopened.
class MissionApplicantsController extends Notifier<MissionApplicantsState> {
  @override
  MissionApplicantsState build() => const MissionApplicantsState();

  Future<void> load(String missionId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final applicants = await ref
          .read(missionsRepositoryProvider)
          .getApplicants(missionId);
      state = state.copyWith(isLoading: false, applicants: applicants);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ref.read(l10nProvider).genericErrorMessage,
      );
    }
  }

  Future<void> select(String missionId, String applicationId) async {
    if (state.processingApplicationIds.contains(applicationId)) return;
    state = state.copyWith(
      processingApplicationIds: {
        ...state.processingApplicationIds,
        applicationId,
      },
      clearError: true,
    );
    try {
      await ref
          .read(missionsRepositoryProvider)
          .selectApplicant(missionId, applicationId);
      state = state.copyWith(
        processingApplicationIds: state.processingApplicationIds
            .where((id) => id != applicationId)
            .toSet(),
        selectedApplicationId: applicationId,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        processingApplicationIds: state.processingApplicationIds
            .where((id) => id != applicationId)
            .toSet(),
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        processingApplicationIds: state.processingApplicationIds
            .where((id) => id != applicationId)
            .toSet(),
        errorMessage: ref.read(l10nProvider).genericErrorMessage,
      );
    }
  }
}

final missionApplicantsControllerProvider = NotifierProvider.autoDispose<
  MissionApplicantsController,
  MissionApplicantsState
>(MissionApplicantsController.new);
