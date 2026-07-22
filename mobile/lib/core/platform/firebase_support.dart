import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// firebase_auth has no official Linux/Windows desktop implementation (unlike
// image_picker, there's no drop-in fallback package for phone auth either —
// see core/auth/phone_verification_service.dart for how that gap is handled).
bool get isFirebaseSupportedPlatform =>
    kIsWeb || Platform.isAndroid || Platform.isIOS;

// Set once in main() to the in-flight Firebase.initializeApp() call, which is
// deliberately never awaited before runApp() (see main.dart) so the splash
// screen's first frame isn't held back. Anything that actually calls a
// Firebase API — today, FirebasePhoneVerificationService — must await this
// first instead, so a slow cold start can't race a Firebase call against
// initialization that hasn't finished yet.
Future<void>? firebaseInitFuture;
