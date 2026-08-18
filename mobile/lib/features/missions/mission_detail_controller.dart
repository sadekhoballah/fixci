import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/location/location_service.dart' as location_service;
import '../../core/network/api_client.dart';
import 'mission_detail_state.dart';
import 'missions_models.dart';
import 'missions_repository.dart';

// Scoped to the mission-detail screen (autoDispose) — a fresh load each time
// it's reopened, same rationale as ServiceRequestController/
// MissionFormController.
class MissionDetailController extends Notifier<MissionDetailState> {
  @override
  MissionDetailState build() => const MissionDetailState();

  Future<void> load(String missionId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final mission = await _fetch(missionId);
    if (mission == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    state = state.copyWith(isLoading: false, mission: mission);
  }

  Future<MissionDetail?> _fetch(String missionId) async {
    // Best-effort position for the distance readout — silently omitted if
    // unavailable, mirrors MissionsBoardController.
    final position = await location_service.getCurrentPosition();
    try {
      return await ref
          .read(missionsRepositoryProvider)
          .getMissionDetail(
            missionId,
            latitude: position?.latitude,
            longitude: position?.longitude,
          );
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(errorMessage: ref.read(l10nProvider).genericErrorMessage);
      return null;
    }
  }

  // Mirrors ServiceRequestController._resolvePosition — same deep-link-to-
  // settings sequence, applied to the "Candidater" tap instead of a service
  // request. Captured fresh here rather than reusing whatever load() found:
  // an applicant's own position at candidature time is what the mission
  // owner should see, not a stale one from when the screen first opened.
  Future<Position?> _resolveApplicantPosition() async {
    final l10n = ref.read(l10nProvider);
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      state = state.copyWith(errorMessage: l10n.enableLocationRetryMessage);
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      state = state.copyWith(errorMessage: l10n.authorizeLocationRetryMessage);
      return null;
    }
    if (permission == LocationPermission.denied) {
      state = state.copyWith(errorMessage: l10n.locationDeniedMessage);
      return null;
    }

    final position = await location_service.getCurrentPosition();
    if (position == null) {
      state = state.copyWith(errorMessage: l10n.unableToGetPositionMessage);
    }
    return position;
  }

  Future<void> apply({String? message}) async {
    final mission = state.mission;
    if (mission == null || state.isApplying) return;
    state = state.copyWith(isApplying: true, clearError: true);

    final position = await _resolveApplicantPosition();
    if (position == null) {
      state = state.copyWith(isApplying: false);
      return;
    }

    try {
      await ref
          .read(missionsRepositoryProvider)
          .applyToMission(
            mission.id,
            latitude: position.latitude,
            longitude: position.longitude,
            message: message,
          );
      // Refetch rather than guess locally — the applicant card's status
      // pill should reflect exactly what the server now has.
      final refreshed = await _fetch(mission.id);
      state = state.copyWith(
        isApplying: false,
        mission: refreshed ?? mission,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isApplying: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isApplying: false,
        errorMessage: ref.read(l10nProvider).genericErrorMessage,
      );
    }
  }

  Future<void> withdraw() => _updateStatus(
    (repository, missionId) => repository.withdrawMission(missionId),
  );

  Future<void> complete() => _updateStatus(
    (repository, missionId) => repository.completeMission(missionId),
  );

  // Shared by withdraw/complete — both are "call an endpoint, then refetch
  // so the status/action buttons reflect the server's truth" with identical
  // busy-state and error handling.
  Future<void> _updateStatus(
    Future<void> Function(MissionsRepository repository, String missionId) action,
  ) async {
    final mission = state.mission;
    if (mission == null || state.isUpdatingStatus) return;
    state = state.copyWith(isUpdatingStatus: true, clearError: true);
    try {
      await action(ref.read(missionsRepositoryProvider), mission.id);
      final refreshed = await _fetch(mission.id);
      state = state.copyWith(
        isUpdatingStatus: false,
        mission: refreshed ?? mission,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isUpdatingStatus: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isUpdatingStatus: false,
        errorMessage: ref.read(l10nProvider).genericErrorMessage,
      );
    }
  }
}

final missionDetailControllerProvider =
    NotifierProvider.autoDispose<MissionDetailController, MissionDetailState>(
      MissionDetailController.new,
    );
