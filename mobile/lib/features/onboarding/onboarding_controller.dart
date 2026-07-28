import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/dev_bypass_session.dart';
import '../../core/auth/session_storage.dart';
import '../../core/auth/user_lookup_service.dart';
import '../../core/media/id_card_picker.dart';
import '../../core/media/image_validation.dart';
import '../../core/models/district.dart';
import '../../core/models/service_category.dart';
import '../../core/models/subscription_tier.dart';
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

  void setFirstName(String value) {
    state = state.copyWith(firstName: value);
  }

  void setLastName(String value) {
    state = state.copyWith(lastName: value);
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

  void setDistrict(District district) {
    state = state.copyWith(district: district);
  }

  void selectTier(SubscriptionTier tier) {
    state = state.copyWith(selectedTier: tier);
  }

  // Persists the currently-selected tier as the artisan's active plan — call
  // this once it's actually active: immediately for the free tier, or after
  // the manual Wave payment confirmation for paid tiers.
  Future<void> confirmActiveTier() async {
    final tier = state.selectedTier;
    if (tier == null) return;
    await ref.read(sessionStorageProvider).saveTier(tier);
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
    // No account (and no real Firebase session on unsupported platforms)
    // exists yet at this point — on those platforms, this is the earliest
    // the phone being registered is known, so it's what dev-bypass auth
    // uses for this call. Harmless no-op on platforms with a real session.
    if (state.phone.trim().isNotEmpty) {
      devBypassPhone = state.phone.trim();
    }
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

  // Called right after OTP verification succeeds. Checks whether this phone
  // already has an account before ever attempting to create one — if it
  // does, logs straight into it instead of hitting the 409 from
  // POST /users/register with no way to recover. Only genuinely new phones
  // fall through to submitRegistration() below.
  Future<bool> completeAfterVerification() async {
    state = state.copyWith(isSubmitting: true, clearSubmissionError: true);
    try {
      final existing = await ref
          .read(userLookupServiceProvider)
          .findExistingAccount();
      if (existing != null) {
        final storage = ref.read(sessionStorageProvider);
        await storage.saveRole(existing.role);
        await storage.savePhone(state.phone.trim());
        if (existing.subscriptionTier != null) {
          await storage.saveTier(existing.subscriptionTier!);
        }
        devBypassPhone = state.phone.trim();
        state = state.copyWith(
          isSubmitting: false,
          registrationSucceeded: true,
          loggedIntoExistingAccount: true,
          role: existing.role,
          selectedTier: existing.subscriptionTier,
        );
        return true;
      }
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
    return submitRegistration();
  }

  Future<bool> submitRegistration() async {
    state = state.copyWith(isSubmitting: true, clearSubmissionError: true);
    try {
      await ref.read(onboardingRepositoryProvider).registerUser(state);
      state = state.copyWith(isSubmitting: false, registrationSucceeded: true);
      final storage = ref.read(sessionStorageProvider);
      await storage.saveRole(state.role!);
      await storage.savePhone(state.phone.trim());
      devBypassPhone = state.phone.trim();
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
