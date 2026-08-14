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
  // on screen far longer than intended. Nothing paints before push
  // notifications need Firebase — several screens later — so it's safe to
  // let this finish in the background; firebaseInitFuture lets that real
  // first user (push_notification_service.dart) await it. Auth doesn't
  // depend on Firebase at all — see core/auth/phone_hint_service.dart
  // (Android's Phone Number Hint API, part of Google Play services, not
  // Firebase) and onboarding_repository.dart.
  if (isFirebaseSupportedPlatform) {
    firebaseInitFuture = Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  runApp(const ProviderScope(child: FixCiApp()));
}
