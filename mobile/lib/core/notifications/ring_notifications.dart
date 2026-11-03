import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// New request offers ring like a phone call on Android: the phone's own
// ringtone, repeated until the craftsman touches the notification, the
// backend says the offer is over, or the offer's deadline passes.
//
// The backend only sends these (data-only pushes with ring = '1') to builds
// that registered their token with ringCapable: true — see
// PushTokenRepository. Everything here must also work from the background
// isolate (main.dart's _firebaseMessagingBackgroundHandler), so no app
// state, only the plugin passed in.

const ringChannel = AndroidNotificationChannel(
  'new_request_ring_v1',
  'Nouvelles demandes (sonnerie)',
  description: 'Sonne comme un appel quand un client demande un artisan',
  importance: Importance.max,
  sound: UriAndroidNotificationSound('content://settings/system/ringtone'),
  audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
  enableVibration: true,
);

// Android's Notification.FLAG_INSISTENT: repeat the sound until the
// notification is touched or removed.
const _flagInsistent = 4;

bool get ringSupported => !kIsWeb && Platform.isAndroid;

Future<void> createRingChannel(FlutterLocalNotificationsPlugin plugin) async {
  await plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(ringChannel);
}

// Stable across isolates and app launches (String.hashCode isn't
// guaranteed to be), so the cancel push finds the right notification.
int ringNotificationId(String requestId) {
  var hash = 0x811c9dc5;
  for (final unit in requestId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

// Returns true when the message was a ring start/stop and has been handled.
Future<bool> handleRingMessage(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, dynamic> data,
) async {
  if (!ringSupported) return false;
  final requestId = data['requestId']?.toString();
  if (requestId == null) return false;

  if (data['event'] == 'request:unavailable') {
    await plugin.cancel(ringNotificationId(requestId));
    return true;
  }
  if (data['ring'] != '1') return false;

  final ringUntil = int.tryParse('${data['ringUntil']}') ?? 0;
  final remainingMs = ringUntil - DateTime.now().millisecondsSinceEpoch;
  if (remainingMs <= 0) return true; // Offer already over — stay quiet.

  await plugin.show(
    ringNotificationId(requestId),
    data['title']?.toString() ?? 'Nouvelle demande',
    data['body']?.toString(),
    NotificationDetails(
      android: AndroidNotificationDetails(
        ringChannel.id,
        ringChannel.name,
        channelDescription: ringChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        additionalFlags: Int32List.fromList([_flagInsistent]),
        timeoutAfter: remainingMs,
        autoCancel: true,
      ),
    ),
    payload: jsonEncode({'event': 'request:new', 'requestId': requestId}),
  );
  return true;
}

// Once the app is on screen the in-app offer card takes over, so any
// ringing notification left (opened from the launcher, not the
// notification) is stopped.
Future<void> cancelAllRinging(FlutterLocalNotificationsPlugin plugin) async {
  if (!ringSupported) return;
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return;
  try {
    final active = await android.getActiveNotifications();
    for (final n in active) {
      if (n.channelId == ringChannel.id && n.id != null) {
        await plugin.cancel(n.id!, tag: n.tag);
      }
    }
  } catch (_) {
    // Best-effort: the notification still stops on its own at the deadline.
  }
}
