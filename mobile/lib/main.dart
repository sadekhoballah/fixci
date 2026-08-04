import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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

// Empty DSN (no --dart-define=SENTRY_DSN=... passed) makes SentryFlutter.init
// silently no-op crash reporting rather than fail — same convention as
// ApiConfig.baseUrl's API_BASE_URL override.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = const bool.fromEnvironment('dart.vm.product')
          ? 'production'
          : 'development';
      options.tracesSampleRate = 0.2;
    },
    appRunner: () {
      // Don't await this before runApp: it's a platform-channel round trip
      // that can take over a second on a cold start, which would otherwise
      // hold the splash screen's first frame back and leave the OS's
      // plain-color splash on screen far longer than intended. Nothing
      // paints before the splash screen needs Firebase — phone verification
      // is the first real user of it, several screens later — so it's safe
      // to let this finish in the background; firebaseInitFuture lets that
      // real first user await it.
      if (isFirebaseSupportedPlatform) {
        firebaseInitFuture = Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
      }
      runApp(const ProviderScope(child: FixCiApp()));
    },
  );
}
