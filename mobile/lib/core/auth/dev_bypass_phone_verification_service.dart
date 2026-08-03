import 'package:flutter/foundation.dart' show kDebugMode;
import 'phone_verification_service.dart';

const devBypassCode = '000000';
const _devBypassVerificationId = 'dev-bypass';

// Only ever selected by phoneVerificationServiceProvider when Firebase isn't
// supported on this platform (desktop) AND kDebugMode is true — see
// onboarding_repository.dart. kDebugMode-gated branches are dead-code-
// eliminated in release/AOT builds, so this class doesn't exist in release
// binaries at all. This constructor check is defense in depth on top of
// that — deliberately a plain runtime check, not assert(), since assert
// bodies are themselves stripped in release and would silently vanish
// exactly when this guard matters.
class DevBypassPhoneVerificationService implements PhoneVerificationService {
  DevBypassPhoneVerificationService() {
    if (!kDebugMode) {
      throw StateError(
        'DevBypassPhoneVerificationService must never run outside debug builds.',
      );
    }
  }

  @override
  Future<void> sendCode({
    required String phoneNumber,
    required void Function(CodeSentResult result) onCodeSent,
    required void Function(String idToken) onAutoVerified,
    required void Function(PhoneVerificationException error) onFailed,
  }) async {
    onCodeSent(CodeSentResult(verificationId: _devBypassVerificationId));
  }

  @override
  Future<String?> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (smsCode != devBypassCode) {
      throw PhoneVerificationException(PhoneVerificationError.invalidCode);
    }
    // No real Firebase session exists on this platform, so there's no ID
    // token to mint — the backend will correctly persist phoneVerified:false
    // for this registration, since nothing was cryptographically confirmed.
    return null;
  }
}
