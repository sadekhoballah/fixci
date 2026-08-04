import 'dart:typed_data';
import '../../core/models/district.dart';
import '../../core/models/service_category.dart';
import '../../core/models/subscription_tier.dart';
import '../../core/models/user_role.dart';

class OnboardingState {
  const OnboardingState({
    this.role,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.phoneCountryCode = 'CI',
    this.district,
    this.serviceCategory,
    this.experienceDetails = '',
    this.idCardStorageKey,
    this.idCardPreviewBytes,
    this.isUploadingIdCard = false,
    this.idCardUploadError,
    this.verifiedPhone,
    this.firebaseIdToken,
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
  final District? district;
  final ServiceCategory? serviceCategory;
  final String experienceDetails;
  final String? idCardStorageKey;
  final Uint8List? idCardPreviewBytes;
  final bool isUploadingIdCard;
  final String? idCardUploadError;
  // The phone number that was successfully OTP-verified, and the Firebase ID
  // token proving it (null on the dev-bypass path — see
  // core/auth/dev_bypass_phone_verification_service.dart). setPhone() clears
  // both if the user edits the number after verifying it.
  final String? verifiedPhone;
  final String? firebaseIdToken;
  final bool isSubmitting;
  final String? submissionError;
  final bool registrationSucceeded;
  // Set once the artisan picks a plan on TierSelectionScreen; persisted via
  // OnboardingController.confirmActiveTier() once it's actually active (free
  // tiers immediately, paid tiers after PaymentCheckoutScreen).
  final SubscriptionTier? selectedTier;
  // True when the phone entered during "registration" turned out to already
  // have an account (GET /users/lookup found it) — the app logged the user
  // straight into that existing account instead of creating a new one, so
  // the post-verification screen should skip the "welcome, new account"
  // flow and go directly to that account's home screen.
  final bool loggedIntoExistingAccount;

  bool get idCardAttached => idCardStorageKey != null;

  bool get isPhoneVerified => verifiedPhone != null && verifiedPhone == phone;

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
    String? verifiedPhone,
    bool clearVerifiedPhone = false,
    String? firebaseIdToken,
    bool clearFirebaseIdToken = false,
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
      verifiedPhone: clearVerifiedPhone
          ? null
          : (verifiedPhone ?? this.verifiedPhone),
      firebaseIdToken: clearFirebaseIdToken
          ? null
          : (firebaseIdToken ?? this.firebaseIdToken),
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
