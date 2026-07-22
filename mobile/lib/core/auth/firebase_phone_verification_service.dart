import 'package:firebase_auth/firebase_auth.dart';
import '../platform/firebase_support.dart';
import 'phone_verification_service.dart';

String _messageForCode(String code) {
  switch (code) {
    case 'invalid-phone-number':
      return 'Numéro de téléphone invalide.';
    case 'too-many-requests':
    case 'quota-exceeded':
      return 'Trop de tentatives. Réessayez plus tard.';
    case 'network-request-failed':
      return 'Impossible de contacter le serveur. Vérifiez votre connexion.';
    case 'invalid-verification-code':
      return 'Code incorrect. Veuillez réessayer.';
    case 'session-expired':
      return 'Le code a expiré. Demandez un nouveau code.';
    default:
      return 'Une erreur est survenue lors de la vérification.';
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
            onFailed(PhoneVerificationException(_messageForCode('')));
            return;
          }
          onAutoVerified(idToken);
        } on FirebaseAuthException catch (e) {
          onFailed(PhoneVerificationException(_messageForCode(e.code)));
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onFailed(PhoneVerificationException(_messageForCode(e.code)));
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
        throw PhoneVerificationException(_messageForCode(''));
      }
      return idToken;
    } on FirebaseAuthException catch (e) {
      throw PhoneVerificationException(_messageForCode(e.code));
    }
  }
}
