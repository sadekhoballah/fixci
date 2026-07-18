import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/media/id_card_picker.dart';
import '../../core/media/image_validation.dart';
import '../../core/models/service_category.dart';
import '../../core/models/user_role.dart';
import '../../core/network/api_client.dart';
import 'onboarding_repository.dart';
import 'onboarding_state.dart';

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void selectRole(UserRole role) {
    state = state.copyWith(role: role);
  }

  void setFullName(String value) {
    state = state.copyWith(fullName: value);
  }

  void setPhone(String value) {
    // Editing the phone after it was verified invalidates that verification
    // — the token/verifiedPhone pair only means something for the exact
    // number it was issued for.
    final stillVerified = value == state.verifiedPhone;
    state = state.copyWith(
      phone: value,
      clearVerifiedPhone: !stillVerified,
      clearFirebaseIdToken: !stillVerified,
    );
  }

  void setVerifiedPhone({required String phone, required String? idToken}) {
    state = state.copyWith(
      verifiedPhone: phone,
      firebaseIdToken: idToken,
      clearFirebaseIdToken: idToken == null,
    );
  }

  void setServiceCategory(ServiceCategory category) {
    state = state.copyWith(serviceCategory: category);
  }

  void setExperienceDetails(String value) {
    state = state.copyWith(experienceDetails: value);
  }

  Future<void> pickIdCardFromGallery() =>
      _pickAndUploadIdCard(ref.read(idCardPickerProvider).pickFromGallery);

  Future<void> pickIdCardFromCamera() =>
      _pickAndUploadIdCard(ref.read(idCardPickerProvider).pickFromCamera);

  Future<void> _pickAndUploadIdCard(
    Future<PickedImage?> Function() pick,
  ) async {
    state = state.copyWith(clearIdCardUploadError: true);
    final PickedImage? image;
    try {
      image = await pick();
    } on IdCardPickerException catch (e) {
      state = state.copyWith(idCardUploadError: e.message);
      return;
    } catch (_) {
      state = state.copyWith(
        idCardUploadError: "Impossible de sélectionner l'image.",
      );
      return;
    }
    if (image == null) return; // user cancelled the picker

    try {
      await validateIdCardImage(image.bytes);
    } on ImageValidationException catch (e) {
      state = state.copyWith(idCardUploadError: e.message);
      return;
    }

    state = state.copyWith(isUploadingIdCard: true, clearIdCardUploadError: true);
    try {
      final storageKey = await ref
          .read(onboardingRepositoryProvider)
          .uploadIdCard(image);
      state = state.copyWith(
        isUploadingIdCard: false,
        idCardStorageKey: storageKey,
        idCardPreviewBytes: Uint8List.fromList(image.bytes),
      );
    } on ApiException catch (e) {
      state = state.copyWith(isUploadingIdCard: false, idCardUploadError: e.message);
    } catch (_) {
      state = state.copyWith(
        isUploadingIdCard: false,
        idCardUploadError: "Échec de l'envoi de l'image.",
      );
    }
  }

  Future<bool> submitRegistration() async {
    state = state.copyWith(isSubmitting: true, clearSubmissionError: true);
    try {
      await ref.read(onboardingRepositoryProvider).registerUser(state);
      state = state.copyWith(isSubmitting: false, registrationSucceeded: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, submissionError: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        submissionError: 'Une erreur inattendue est survenue.',
      );
      return false;
    }
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
