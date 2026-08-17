import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/phone_hint_service.dart';
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
import 'allowed_countries.dart';
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

  // Manual typing path — the iOS field, and the Android fallback once the
  // Phone Number Hint API has come back empty. Never reachable while
  // phoneLocked is true (the field is read-only in the UI at that point),
  // but resets phoneSource defensively in case that ever changes.
  void setPhone(String value) {
    state = state.copyWith(
      phone: value,
      phoneLocked: false,
      phoneSource: PhoneSource.manual,
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

  // Android only (see PhoneHintService.isSupported) — launches the system
  // phone-number picker and, on a result, locks the field to whatever was
  // picked. A null result (no numbers on the device, or the user dismissed
  // the picker — Android doesn't distinguish the two) leaves the field
  // exactly as it was: unlocked and empty, i.e. the manual-entry fallback,
  // with nothing further to do here. Also used to *re*-open the picker for
  // a dual-SIM switch — see _PhoneField in registration_screen.dart, which
  // routes both the initial request and every "change" gesture through
  // this same method while locked.
  Future<void> requestPhoneHint() async {
    final service = ref.read(phoneHintServiceProvider);
    if (!service.isSupported) return;

    state = state.copyWith(isRequestingPhoneHint: true);
    final raw = await service.requestHint();
    if (raw == null) {
      state = state.copyWith(isRequestingPhoneHint: false);
      return;
    }

    final parsed = parsePhoneHint(
      raw,
      allowedCountries: allowedCountries,
      currentCountryIsoCode: state.phoneCountryCode,
    );
    final countryChanged = parsed.countryIsoCode != state.phoneCountryCode;
    state = state.copyWith(
      phone: parsed.e164Number,
      phoneCountryCode: parsed.countryIsoCode,
      phoneLocked: true,
      phoneSource: PhoneSource.deviceHint,
      isRequestingPhoneHint: false,
      clearDistrict: countryChanged,
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

  // Second mandatory document, taxi/camion only — reuses the same
  // idCardPickerProvider (a generic photo picker despite its name) and the
  // same image-shape validation as the ID card above; only the upload
  // endpoint and the state fields it writes into differ.
  Future<void> pickLicenseFromGallery() =>
      _pickAndUploadLicense(ref.read(idCardPickerProvider).pickFromGallery);

  Future<void> pickLicenseFromCamera() =>
      _pickAndUploadLicense(ref.read(idCardPickerProvider).pickFromCamera);

  Future<void> _pickAndUploadLicense(
    Future<PickedImage?> Function() pick,
  ) async {
    state = state.copyWith(clearLicenseUploadError: true);
    final l10n = ref.read(l10nProvider);
    final PickedImage? image;
    try {
      image = await pick();
    } on IdCardPickerException catch (e) {
      state = state.copyWith(
        licenseUploadError: e.error.localizedMessage(l10n),
      );
      return;
    } catch (_) {
      state = state.copyWith(
        licenseUploadError: l10n.unableToSelectImageMessage,
      );
      return;
    }
    if (image == null) return; // user cancelled the picker

    try {
      await validateIdCardImage(image.bytes);
    } on ImageValidationException catch (e) {
      state = state.copyWith(
        licenseUploadError: e.error.localizedMessage(l10n),
      );
      return;
    }

    state = state.copyWith(
      isUploadingLicense: true,
      clearLicenseUploadError: true,
    );
    try {
      final storageKey = await ref
          .read(onboardingRepositoryProvider)
          .uploadLicense(image);
      state = state.copyWith(
        isUploadingLicense: false,
        licenseStorageKey: storageKey,
        licensePreviewBytes: Uint8List.fromList(image.bytes),
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isUploadingLicense: false,
        licenseUploadError: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        isUploadingLicense: false,
        licenseUploadError: l10n.licenseSendFailedMessage,
      );
    }
  }

  // No phone verification happens before this for this phase (see
  // backend/src/database/entities/user.entity.ts's phoneVerified column
  // comment) — POST /users/register is called directly with whatever
  // number is in state.phone. A 409 means that number already has an
  // account: for a device-sourced number (PhoneSource.deviceHint) that's
  // treated as a login via POST /auth/reconnect; for a manually-typed one
  // it isn't, since there's no possession signal behind it at all — see
  // OnboardingState.PhoneSource and auth.controller.ts's doc comment.
  Future<bool> completeRegistration() async {
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
      if (e.statusCode == 409 && state.phoneSource == PhoneSource.deviceHint) {
        return _reconnectExistingAccount();
      }
      if (e.statusCode == 409) {
        state = state.copyWith(
          isSubmitting: false,
          submissionError: l10n.phoneAlreadyRegisteredManualMessage,
        );
        return false;
      }
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

  Future<bool> _reconnectExistingAccount() async {
    final l10n = ref.read(l10nProvider);
    try {
      final session = await ref
          .read(onboardingRepositoryProvider)
          .reconnect(state.phone.trim());
      await ref
          .read(tokenStorageProvider)
          .saveTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
          );
      final storage = ref.read(sessionStorageProvider);
      await storage.saveRole(session.role);
      await storage.savePhone(state.phone.trim());
      if (session.subscriptionTier != null) {
        await storage.saveTier(session.subscriptionTier!);
      }
      state = state.copyWith(
        isSubmitting: false,
        registrationSucceeded: true,
        loggedIntoExistingAccount: true,
        role: session.role,
        selectedTier: session.subscriptionTier,
      );
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
