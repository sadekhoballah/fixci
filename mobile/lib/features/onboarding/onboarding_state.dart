import 'dart:typed_data';
import '../../core/models/district.dart';
import '../../core/models/service_category.dart';
import '../../core/models/subscription_tier.dart';
import '../../core/models/user_role.dart';

// Where OnboardingState.phone came from — decides how OnboardingController
// reacts to a "phone already registered" conflict from POST /users/register
// (see completeRegistration): a device-sourced number gets a best-effort
// reconnect via POST /auth/reconnect, a manually-typed one doesn't, because
// there's no possession signal at all behind it. See
// backend/src/auth/reconnect.controller.ts's doc comment for the full
// rationale — this is the one enum value that phase 2's real verification
// will need to touch.
enum PhoneSource { deviceHint, manual }

class OnboardingState {
  const OnboardingState({
    this.role,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.phoneCountryCode = 'CI',
    this.phoneLocked = false,
    this.phoneSource = PhoneSource.manual,
    this.isRequestingPhoneHint = false,
    this.district,
    this.serviceCategory,
    this.experienceDetails = '',
    this.idCardStorageKey,
    this.idCardPreviewBytes,
    this.isUploadingIdCard = false,
    this.idCardUploadError,
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
  // "no numbers on this device" fallback.
  final bool phoneLocked;
  final PhoneSource phoneSource;
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
  final bool isSubmitting;
  final String? submissionError;
  final bool registrationSucceeded;
  // Set once the artisan picks a plan on TierSelectionScreen, or (for a
  // returning craftsman) straight from POST /auth/reconnect's response —
  // persisted via OnboardingController.confirmActiveTier() once it's
  // actually active (free tiers immediately, paid tiers after
  // PaymentCheckoutScreen).
  final SubscriptionTier? selectedTier;
  // True when phone turned out to already have an account and
  // OnboardingController.completeRegistration() logged the caller straight
  // into it via POST /auth/reconnect (device-sourced number only — see
  // PhoneSource) instead of creating a new one, so the post-registration
  // screen should skip the "welcome, new account" flow and go directly to
  // that account's home screen.
  final bool loggedIntoExistingAccount;

  bool get idCardAttached => idCardStorageKey != null;

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
    if (!idCardAttached) return false;
    if (role == UserRole.craftsman) {
      return serviceCategory != null && experienceDetails.trim().isNotEmpty;
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
    PhoneSource? phoneSource,
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
      phoneSource: phoneSource ?? this.phoneSource,
      isRequestingPhoneHint: isRequestingPhoneHint ?? this.isRequestingPhoneHint,
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
