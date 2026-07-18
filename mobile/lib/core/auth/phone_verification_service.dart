class PhoneVerificationException implements Exception {
  PhoneVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
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
