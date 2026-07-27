import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_role.dart';
import '../navigation/navigator_key.dart';
import '../platform/firebase_support.dart';
import 'push_token_repository.dart';
import '../../features/client_home/screens/client_shell_screen.dart';
import '../../features/craftsman_home/screens/artisan_shell_screen.dart';

// Matches AndroidManifest.xml's default_notification_channel_id — must stay
// in sync, since a mismatch means Android silently drops the channel
// customization (falls back to a generic "Miscellaneous" one).
const _androidChannel = AndroidNotificationChannel(
  'fixci_default_channel',
  'Notifications FixCi',
  description: 'Suivi de vos demandes et missions',
  importance: Importance.high,
);

// The fallback delivery path for matching events (request:new,
// request:assigned, ...) when the socket connection can't reach the app —
// backgrounded, or the OS killed it outright. Sockets stay the primary,
// faster path; this only needs to eventually get the user back into the
// app. See NotificationsService on the backend for the other half.
class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _isSupportedPlatform =>
      kIsWeb || Platform.isAndroid || Platform.isIOS;

  // Called once from ArtisanShellScreen/ClientShellScreen's initState — both
  // are the single choke point every "already logged in" path (splash
  // restore, fresh registration, fresh login) passes through, so this is
  // the one place that needs to run rather than every screen that can lead
  // there. Safe to call more than once (e.g. if a shell were ever
  // recreated) — everything past the guard is idempotent registration.
  Future<void> init({required UserRole role}) async {
    if (!_isSupportedPlatform || _initialized) return;
    _initialized = true;
    await firebaseInitFuture;

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // Nothing more to do — the user declined, and re-prompting isn't
      // possible on iOS short of sending them to Settings, which is out of
      // scope for the MVP. Sockets remain the delivery path while the app
      // is open.
      return;
    }

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _handleTapPayload(response.payload, role),
    );

    unawaited(_registerToken());
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _registerToken());

    // Foreground messages never auto-display (that's an OS behavior for
    // background/terminated only) — show one ourselves so a request update
    // isn't silently invisible just because the app happened to be open.
    FirebaseMessaging.onMessage.listen((message) => _showLocalNotification(message));

    // App was backgrounded (not killed) and the user tapped the system
    // notification — the Dart isolate is already alive, so this fires
    // directly.
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _navigateForEvent(_stringifyData(message.data), role),
    );

    // App was killed outright and got cold-started *by* tapping the
    // notification — the only way to recover that tap once we're back up.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigateForEvent(_stringifyData(initialMessage.data), role);
    }
  }

  Future<void> _registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _ref.read(pushTokenRepositoryProvider).registerToken(token);
    } catch (_) {
      // Best-effort — sockets still work for as long as the app stays
      // open/foregrounded; this just means the background fallback won't
      // be registered until the next successful attempt (next launch, or
      // the next onTokenRefresh).
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleTapPayload(String? payload, UserRole role) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateForEvent(_stringifyData(data), role);
    } catch (_) {
      // Malformed/unexpected payload — nothing to navigate to.
    }
  }

  Map<String, String> _stringifyData(Map<String, dynamic> data) =>
      data.map((key, value) => MapEntry(key, '$value'));

  // MVP scope: every event just brings the user back to their role's Home
  // shell (which already re-fetches live/active-request state on its own —
  // see LiveRequestsController.loadActiveJob and
  // ServiceRequestController.handleAppResumed) rather than deep-linking to
  // a specific sub-screen. Good enough for "I got a push, let me open the
  // app and see what's going on"; a future pass could route more precisely
  // per event type.
  void _navigateForEvent(Map<String, String> data, UserRole role) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    final destination = role == UserRole.craftsman
        ? const ArtisanShellScreen()
        : const ClientShellScreen();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(ref),
);
