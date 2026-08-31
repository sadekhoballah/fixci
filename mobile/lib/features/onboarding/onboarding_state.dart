import 'dart:typed_data';
import '../../core/models/district.dart';
import '../../core/models/service_category.dart';
import '../../core/models/subscription_tier.dart';
import '../../core/models/user_role.dart';

// Play-Store-review / pilot numbers that skip OTP delivery (verify with
// 000000) AND are exempt from the mandatory ID-document upload — mirrors the
// backend OTP_TEST_PHONES allowlist (see backend/src/auth/otp-test-phones.ts).
// Must be kept in sync with that env var for the numbers a reviewer uses.
const kOtpBypassPhones = {'+2250707070707', '+2250808080808'};

class OnboardingState {
  const OnboardingState({
    this.role,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.phoneCountryCode = 'CI',
    this.phoneLocked = false,
    this.isRequestingPhoneHint = false,
    this.district,
    this.serviceCategory,
    this.experienceDetails = '',
    this.idCardStorageKey,
    this.idCardPreviewBytes,
    this.isUploadingIdCard = false,
    this.idCardUploadError,
    this.licenseStorageKey,
    this.licensePreviewBytes,
    this.isUploadingLicense = false,
    this.licenseUploadError,
    this.verifiedPhone,
    this.registrationToken,
    this.isSubmitting = false,
    this.submissionError,
    this.registrationSucceeded = false,
    this.selectedTier,
    this.loggedIntoExistingAccount = false,
  });

  final UserRole? role;
  final String firstName;
  final String lastName;
  final String phone;
  // ISO 3166-1 alpha-2 of whichever country is currently selected in the
  // phone field's IntlPhoneField (registration_screen.dart) — matches its
  // own `initialCountryCode: 'CI'`. Drives _DistrictPicker's filtering and
  // the Russia "coming soon" gate; not itself sent to the backend (the
  // phone number's own dial code already encodes it there).
  final String phoneCountryCode;
  // True once a number picked via the Android Phone Number Hint API has
  // been applied — the phone field goes read-only and the country selector
  // stops accepting manual taps while this is true (see
  // registration_screen.dart's _PhoneField). Never true on iOS or after the
  // "no numbers on this device" fallback. Purely a prefill convenience now:
  // ownership is proven by OTP, not by where the number came from.
  final bool phoneLocked;
  // Drives the phone field's loading state while the system picker is being
  // requested/shown — separate from phoneLocked since this is true only
  // during the request itself.
  final bool isRequestingPhoneHint;
  final District? district;
  final ServiceCategory? serviceCategory;
  final String experienceDetails;
  final String? idCardStorageKey;
  final Uint8List? idCardPreviewBytes;
  final bool isUploadingIdCard;
  final String? idCardUploadError;
  // Second mandatory document, only shown/required for a craftsman whose
  // serviceCategory.requiresDriverLicense is true (taxi/camion) — see
  // isRegistrationComplete below and registration_screen.dart's
  // _LicensePicker.
  final String? licenseStorageKey;
  final Uint8List? licensePreviewBytes;
  final bool isUploadingLicense;
  final String? licenseUploadError;
  // The phone number that Twilio Verify approved a code for, and the
  // short-lived proof of that for a brand-new phone (null once
  // loggedIntoExistingAccount is true — /auth/otp/check already logged that
  // case straight in, see OnboardingController.setVerifiedPhone).
  // setPhone() clears both if the user edits the number after verifying it.
  final String? verifiedPhone;
  final String? registrationToken;
  final bool isSubmitting;
  final String? submissionError;
  final bool registrationSucceeded;
  // Set once the artisan picks a plan on TierSelectionScreen, or (for a
  // returning craftsman) straight from POST /auth/otp/check's response —
  // persisted via OnboardingController.confirmActiveTier() once it's
  // actually active (free tiers immediately, paid tiers after
  // PaymentCheckoutScreen).
  final SubscriptionTier? selectedTier;
  // True when the phone entered during "registration" turned out to already
  // have an account (POST /auth/otp/check returned status:"existing") — the
  // app logged the user straight into that existing account instead of
  // creating a new one, so the post-verification screen should skip the
  // "welcome, new account" flow and go directly to that account's home
  // screen.
  final bool loggedIntoExistingAccount;

  bool get idCardAttached => idCardStorageKey != null;
  bool get licenseAttached => licenseStorageKey != null;

  // A reviewer/pilot number registers with no KYC document at all — the
  // backend waives the same requirement for these numbers.
  bool get idDocumentWaived => kOtpBypassPhones.contains(phone.trim());

  bool get isPhoneVerified =>
      verifiedPhone != null && verifiedPhone == phone;

  // Every field is required — mirrors the ID card the photo is meant to
  // match, so first/last name are collected (and validated) separately
  // rather than as one freeform "full name" box.
  String get fullName => '$firstName $lastName'.trim();

  // No districts are seeded for this market yet — see _DistrictPicker's
  // "coming soon" notice, shown in place of the (always-empty) picker.
  bool get isCountryLaunched => phoneCountryCode != 'RU';

  bool get isRegistrationComplete {
    if (!isCountryLaunched) return false;
    if (firstName.trim().isEmpty) return false;
    if (lastName.trim().isEmpty) return false;
    if (phone.trim().isEmpty) return false;
    if (district == null) return false;
    if (!idCardAttached && !idDocumentWaived) return false;
    if (role == UserRole.craftsman) {
      if (serviceCategory == null || experienceDetails.trim().isEmpty) {
        return false;
      }
      if (serviceCategory!.requiresDriverLicense &&
          !licenseAttached &&
          !idDocumentWaived) {
        return false;
      }
      return true;
    }
    return true;
  }

  OnboardingState copyWith({
    UserRole? role,
    String? firstName,
    String? lastName,
    String? phone,
    String? phoneCountryCode,
    bool? phoneLocked,
    bool? isRequestingPhoneHint,
    District? district,
    bool clearDistrict = false,
    ServiceCategory? serviceCategory,
    String? experienceDetails,
    String? idCardStorageKey,
    bool clearIdCard = false,
    Uint8List? idCardPreviewBytes,
    bool? isUploadingIdCard,
    String? idCardUploadError,
    bool clearIdCardUploadError = false,
    String? licenseStorageKey,
    bool clearLicense = false,
    Uint8List? licensePreviewBytes,
    bool? isUploadingLicense,
    String? licenseUploadError,
    bool clearLicenseUploadError = false,
    String? verifiedPhone,
    bool clearVerifiedPhone = false,
    String? registrationToken,
    bool clearRegistrationToken = false,
    bool? isSubmitting,
    String? submissionError,
    bool clearSubmissionError = false,
    bool? registrationSucceeded,
    SubscriptionTier? selectedTier,
    bool? loggedIntoExistingAccount,
  }) {
    return OnboardingState(
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      phoneCountryCode: phoneCountryCode ?? this.phoneCountryCode,
      phoneLocked: phoneLocked ?? this.phoneLocked,
      isRequestingPhoneHint:
          isRequestingPhoneHint ?? this.isRequestingPhoneHint,
      district: clearDistrict ? null : (district ?? this.district),
      serviceCategory: serviceCategory ?? this.serviceCategory,
      experienceDetails: experienceDetails ?? this.experienceDetails,
      idCardStorageKey: clearIdCard
          ? null
          : (idCardStorageKey ?? this.idCardStorageKey),
      idCardPreviewBytes: clearIdCard
          ? null
          : (idCardPreviewBytes ?? this.idCardPreviewBytes),
      isUploadingIdCard: isUploadingIdCard ?? this.isUploadingIdCard,
      idCardUploadError: clearIdCardUploadError
          ? null
          : (idCardUploadError ?? this.idCardUploadError),
      licenseStorageKey: clearLicense
          ? null
          : (licenseStorageKey ?? this.licenseStorageKey),
      licensePreviewBytes: clearLicense
          ? null
          : (licensePreviewBytes ?? this.licensePreviewBytes),
      isUploadingLicense: isUploadingLicense ?? this.isUploadingLicense,
      licenseUploadError: clearLicenseUploadError
          ? null
          : (licenseUploadError ?? this.licenseUploadError),
      verifiedPhone: clearVerifiedPhone
          ? null
          : (verifiedPhone ?? this.verifiedPhone),
      registrationToken: clearRegistrationToken
          ? null
          : (registrationToken ?? this.registrationToken),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionError: clearSubmissionError
          ? null
          : (submissionError ?? this.submissionError),
      registrationSucceeded:
          registrationSucceeded ?? this.registrationSucceeded,
      selectedTier: selectedTier ?? this.selectedTier,
      loggedIntoExistingAccount:
          loggedIntoExistingAccount ?? this.loggedIntoExistingAccount,
    );
  }
}
