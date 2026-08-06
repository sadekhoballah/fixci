import '../../l10n/app_localizations.dart';

enum PhoneVerificationError {
  invalidPhoneNumber,
  tooManyAttempts,
  networkError,
  invalidCode,
  codeExpired,
  unknown,
}

extension PhoneVerificationErrorLocalization on PhoneVerificationError {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    PhoneVerificationError.invalidPhoneNumber => l10n.invalidPhoneNumberMessage,
    PhoneVerificationError.tooManyAttempts => l10n.tooManyAttemptsMessage,
    PhoneVerificationError.networkError => l10n.networkConnectionErrorMessage,
    PhoneVerificationError.invalidCode => l10n.invalidCodeMessage,
    PhoneVerificationError.codeExpired => l10n.codeExpiredMessage,
    PhoneVerificationError.unknown => l10n.verificationErrorMessage,
  };
}

class PhoneVerificationException implements Exception {
  PhoneVerificationException(this.error, {this.debugDetail});

  final PhoneVerificationError error;

  // TEMP DIAGNOSTIC: raw "[code] message" from the underlying
  // FirebaseAuthException, surfaced in the UI so the real Firebase error can
  // be identified without needing device logs. Remove once the phone-auth
  // root cause is found — see firebase_phone_verification_service.dart.
  final String? debugDetail;

  @override
  String toString() => error.name;
}

class CodeSentResult {
  CodeSentResult({required this.verificationId});

  final String verificationId;
}

// The fakeable I/O boundary for phone verification — mirrors IdCardPicker's
// shape (core/media/id_card_picker.dart). Real implementation talks to
// Firebase; on platforms Firebase doesn't support, a dev-only bypass
// implementation is used instead (see dev_bypass_phone_verification_service.dart).
abstract class PhoneVerificationService {
  // Sends an SMS code to [phoneNumber]. Some platforms (Android, via Play
  // Integrity) can auto-verify without the user ever seeing a code screen —
  // when that happens, [onAutoVerified] fires with a ready-to-use ID token
  // instead of [onCodeSent].
  Future<void> sendCode({
    required String phoneNumber,
    required void Function(CodeSentResult result) onCodeSent,
    required void Function(String idToken) onAutoVerified,
    required void Function(PhoneVerificationException error) onFailed,
  });

  // Confirms a user-entered code and returns a Firebase ID token proving the
  // phone was verified — or null if the code was accepted but no real
  // Firebase session exists to mint a token from (the dev bypass). Throws
  // PhoneVerificationException on a wrong or expired code.
  Future<String?> confirmCode({
    required String verificationId,
    required String smsCode,
  });
}
