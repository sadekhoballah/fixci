import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/platform/firebase_support.dart';

// Runs in a separate background isolate with no state from main() carried
// over — FCM requires this to be a top-level (or static) function, and it
// must re-initialize Firebase itself since this isolate never ran main().
// Just existing is enough to satisfy FirebaseMessaging.onBackgroundMessage;
// the actual notification is already shown by the OS from the "notification"
// payload the backend sends (see NotificationsService), not by code here —
// this hook is only for data-only messages, which FixCi doesn't send today.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Don't await this before runApp: it's a platform-channel round trip that
  // can take over a second on a cold start, which would otherwise hold the
  // splash screen's first frame back and leave the OS's plain-color splash
  // on screen far longer than intended. Nothing paints before the splash
  // screen needs Firebase — phone verification is the first real user of it,
  // several screens later — so it's safe to let this finish in the
  // background; firebaseInitFuture lets that real first user await it.
  if (isFirebaseSupportedPlatform) {
    // App Check must be activated before any Firebase Auth call (phone
    // verification included) or Firebase silently rejects the request as
    // missing an App Check token. Chaining it onto firebaseInitFuture itself
    // — rather than firing it off separately — means every existing
    // `await firebaseInitFuture` call site (phone verification, push
    // notifications, current_auth_token) is automatically covered without
    // having to hunt down each one.
    firebaseInitFuture = Firebase.initializeApp().then(
      (_) => FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      ),
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  runApp(const ProviderScope(child: FixCiApp()));
}
