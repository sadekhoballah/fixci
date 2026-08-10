import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/otp_auth_service.dart';
import '../../core/auth/session_storage.dart';
import '../../core/auth/token_storage.dart';
import '../../core/localization/locale_controller.dart';
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
      clearRegistrationToken: !stillVerified,
    );
  }

  // Fired from IntlPhoneField's onCountryChanged — a previously picked
  // district almost certainly doesn't belong to the newly selected country
  // (see District.countryCode/_DistrictPicker's filtering), so it's cleared
  // rather than left silently pointing at the wrong market.
  void setPhoneCountryCode(String isoCode) {
    if (isoCode == state.phoneCountryCode) return;
    state = state.copyWith(phoneCountryCode: isoCode, clearDistrict: true);
  }

  // Called right after OTP verification succeeds. POST /auth/verify-otp
  // already tells us whether this phone has an account (see
  // otp_auth_service.dart) — an ExistingUserSession means the caller is
  // logged in immediately (tokens persisted below, exactly like a
  // successful POST /users/register would); a NewUserVerified just carries
  // proof-of-verification for that register call to use later.
  Future<void> setVerifiedPhone({
    required String phone,
    required VerifyOtpOutcome outcome,
  }) async {
    switch (outcome) {
      case ExistingUserSession():
        await ref.read(tokenStorageProvider).saveTokens(
          accessToken: outcome.accessToken,
          refreshToken: outcome.refreshToken,
        );
        final storage = ref.read(sessionStorageProvider);
        await storage.saveRole(outcome.role);
        await storage.savePhone(phone);
        if (outcome.subscriptionTier != null) {
          await storage.saveTier(outcome.subscriptionTier!);
        }
        state = state.copyWith(
          verifiedPhone: phone,
          clearRegistrationToken: true,
          loggedIntoExistingAccount: true,
          role: outcome.role,
          selectedTier: outcome.subscriptionTier,
        );
      case NewUserVerified():
        state = state.copyWith(
          verifiedPhone: phone,
          registrationToken: outcome.registrationToken,
        );
    }
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
    final l10n = ref.read(l10nProvider);
    final PickedImage? image;
    try {
      image = await pick();
    } on IdCardPickerException catch (e) {
      state = state.copyWith(
        idCardUploadError: e.error.localizedMessage(l10n),
      );
      return;
    } catch (_) {
      state = state.copyWith(
        idCardUploadError: l10n.unableToSelectImageMessage,
      );
      return;
    }
    if (image == null) return; // user cancelled the picker

    try {
      await validateIdCardImage(image.bytes);
    } on ImageValidationException catch (e) {
      state = state.copyWith(
        idCardUploadError: e.error.localizedMessage(l10n),
      );
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
        idCardUploadError: l10n.idCardSendFailedMessage,
      );
    }
  }

  // Called right after OTP verification succeeds. POST /auth/verify-otp
  // already told us whether this phone has an account — see
  // OnboardingController.setVerifiedPhone, which set
  // loggedIntoExistingAccount and persisted a full session for that case.
  // Only genuinely new phones fall through to submitRegistration() below.
  Future<bool> completeAfterVerification() async {
    if (state.loggedIntoExistingAccount) {
      state = state.copyWith(registrationSucceeded: true);
      return true;
    }
    return submitRegistration();
  }

  Future<bool> submitRegistration() async {
    state = state.copyWith(isSubmitting: true, clearSubmissionError: true);
    final l10n = ref.read(l10nProvider);
    try {
      final tokens = await ref
          .read(onboardingRepositoryProvider)
          .registerUser(state);
      await ref
          .read(tokenStorageProvider)
          .saveTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
          );
      final storage = ref.read(sessionStorageProvider);
      await storage.saveRole(state.role!);
      await storage.savePhone(state.phone.trim());
      state = state.copyWith(isSubmitting: false, registrationSucceeded: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, submissionError: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        submissionError: l10n.unexpectedErrorMessage,
      );
      return false;
    }
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
