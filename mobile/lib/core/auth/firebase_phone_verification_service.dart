import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../platform/firebase_support.dart';
import 'phone_verification_service.dart';

// TEMP DIAGNOSTIC: logs the exact FirebaseAuthException and builds the
// PhoneVerificationException that carries it through to the UI. Remove once
// the phone-auth root cause is found (see debugDetail in
// phone_verification_service.dart).
PhoneVerificationException _diagnosticException(FirebaseAuthException e) {
  debugPrint(
    'FIREBASE_PHONE_AUTH_ERROR code=${e.code} message=${e.message}\n'
    'stackTrace=${e.stackTrace}',
  );
  return PhoneVerificationException(
    _errorForCode(e.code),
    debugDetail: '[${e.code}] ${e.message}',
  );
}

PhoneVerificationError _errorForCode(String code) {
  switch (code) {
    case 'invalid-phone-number':
      return PhoneVerificationError.invalidPhoneNumber;
    case 'too-many-requests':
    case 'quota-exceeded':
      return PhoneVerificationError.tooManyAttempts;
    case 'network-request-failed':
      return PhoneVerificationError.networkError;
    case 'invalid-verification-code':
      return PhoneVerificationError.invalidCode;
    case 'session-expired':
      return PhoneVerificationError.codeExpired;
    default:
      return PhoneVerificationError.unknown;
  }
}

class FirebasePhoneVerificationService implements PhoneVerificationService {
  @override
  Future<void> sendCode({
    required String phoneNumber,
    required void Function(CodeSentResult result) onCodeSent,
    required void Function(String idToken) onAutoVerified,
    required void Function(PhoneVerificationException error) onFailed,
  }) async {
    // main() deliberately doesn't await Firebase.initializeApp() before the
    // first frame (see firebaseInitFuture's doc comment) — this is the
    // actual first call into a Firebase API, so it's the one that must wait.
    await firebaseInitFuture;
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          final idToken = await userCredential.user?.getIdToken();
          if (idToken == null) {
            onFailed(PhoneVerificationException(_errorForCode('')));
            return;
          }
          onAutoVerified(idToken);
        } on FirebaseAuthException catch (e) {
          onFailed(_diagnosticException(e));
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onFailed(_diagnosticException(e));
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(CodeSentResult(verificationId: verificationId));
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // No-op: the user can still type the code manually with this
        // verificationId, they just won't get auto-fill.
      },
    );
  }

  @override
  Future<String?> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    await firebaseInitFuture;
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        throw PhoneVerificationException(_errorForCode(''));
      }
      return idToken;
    } on FirebaseAuthException catch (e) {
      throw _diagnosticException(e);
    }
  }
}
