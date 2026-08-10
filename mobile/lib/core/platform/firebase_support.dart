import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// firebase_messaging (push notifications, the only remaining Firebase
// consumer — auth no longer uses Firebase at all, see
// core/auth/otp_auth_service.dart) has no official Linux/Windows desktop
// implementation.
bool get isFirebaseSupportedPlatform =>
    kIsWeb || Platform.isAndroid || Platform.isIOS;

// Set once in main() to the in-flight Firebase.initializeApp() call, which is
// deliberately never awaited before runApp() (see main.dart) so the splash
// screen's first frame isn't held back. Anything that actually calls a
// Firebase API — today, PushNotificationService — must await this first
// instead, so a slow cold start can't race a Firebase call against
// initialization that hasn't finished yet.
Future<void>? firebaseInitFuture;
