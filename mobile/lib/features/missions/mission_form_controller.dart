import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/location/location_service.dart' as location_service;
import '../../core/media/id_card_picker.dart';
import '../../core/media/image_validation.dart';
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';
import 'mission_form_state.dart';
import 'missions_repository.dart';

// Scoped to the create-mission screen (autoDispose) — a fresh attempt starts
// clean each time the screen reopens, same rationale as
// ServiceRequestController.
class MissionFormController extends Notifier<MissionFormState> {
  @override
  MissionFormState build() => const MissionFormState();

  Future<void> addPhotoFromGallery() =>
      _addPhoto(ref.read(idCardPickerProvider).pickFromGallery);

  Future<void> addPhotoFromCamera() =>
      _addPhoto(ref.read(idCardPickerProvider).pickFromCamera);

  Future<void> _addPhoto(Future<PickedImage?> Function() pick) async {
    if (state.photos.length >= maxMissionPhotos || state.isUploadingPhoto) {
      return;
    }
    state = state.copyWith(clearError: true);
    final l10n = ref.read(l10nProvider);
    final PickedImage? image;
    try {
      image = await pick();
    } on IdCardPickerException catch (e) {
      state = state.copyWith(errorMessage: e.error.localizedMessage(l10n));
      return;
    } catch (_) {
      state = state.copyWith(errorMessage: l10n.unableToSelectImageMessage);
      return;
    }
    if (image == null) return; // user cancelled the picker

    try {
      await validateGenericPhotoImage(image.bytes);
    } on ImageValidationException catch (e) {
      state = state.copyWith(errorMessage: e.error.localizedMessage(l10n));
      return;
    }

    state = state.copyWith(isUploadingPhoto: true, clearError: true);
    try {
      final storageKey = await ref
          .read(missionsRepositoryProvider)
          .uploadMissionPhoto(image);
      state = state.copyWith(
        isUploadingPhoto: false,
        photos: [
          ...state.photos,
          MissionPhotoDraft(
            bytes: Uint8List.fromList(image.bytes),
            storageKey: storageKey,
          ),
        ],
      );
    } on ApiException catch (e) {
      state = state.copyWith(isUploadingPhoto: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isUploadingPhoto: false,
        errorMessage: l10n.genericErrorMessage,
      );
    }
  }

  void removePhoto(int index) {
    final photos = [...state.photos]..removeAt(index);
    state = state.copyWith(photos: photos);
  }

  // Mirrors ServiceRequestController._resolvePosition — same deep-link-to-
  // settings sequence, applied to the mission's own location instead of the
  // client's request location.
  Future<Position?> _resolvePosition() async {
    final l10n = ref.read(l10nProvider);
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      state = state.copyWith(
        status: MissionFormStatus.error,
        errorMessage: l10n.enableLocationRetryMessage,
      );
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      state = state.copyWith(
        status: MissionFormStatus.error,
        errorMessage: l10n.authorizeLocationRetryMessage,
      );
      return null;
    }
    if (permission == LocationPermission.denied) {
      state = state.copyWith(
        status: MissionFormStatus.error,
        errorMessage: l10n.locationDeniedMessage,
      );
      return null;
    }

    final position = await location_service.getCurrentPosition();
    if (position == null) {
      state = state.copyWith(
        status: MissionFormStatus.error,
        errorMessage: l10n.unableToGetPositionMessage,
      );
    }
    return position;
  }

  Future<void> submit({
    required String title,
    required String description,
    required String locationAddress,
    ServiceCategory? category,
  }) async {
    state = state.copyWith(status: MissionFormStatus.locating, clearError: true);
    final position = await _resolvePosition();
    if (position == null) return;

    state = state.copyWith(status: MissionFormStatus.submitting);
    try {
      final created = await ref
          .read(missionsRepositoryProvider)
          .createMission(
            title: title,
            description: description,
            locationAddress: locationAddress,
            latitude: position.latitude,
            longitude: position.longitude,
            category: category,
            photoStorageKeys: state.photos.map((p) => p.storageKey).toList(),
          );
      state = state.copyWith(
        status: MissionFormStatus.success,
        createdMissionId: created.id,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: MissionFormStatus.error,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: MissionFormStatus.error,
        errorMessage: ref.read(l10nProvider).genericErrorMessage,
      );
    }
  }
}

final missionFormControllerProvider =
    NotifierProvider.autoDispose<MissionFormController, MissionFormState>(
      MissionFormController.new,
    );
