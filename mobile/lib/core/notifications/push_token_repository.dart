import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

class PushTokenRepository {
  PushTokenRepository(this._apiClient);

  final ApiClient _apiClient;

  // ringCapable tells the backend this build can ring for new requests
  // (ring_notifications.dart); web has no background handler to do it.
  Future<void> registerToken(String fcmToken) => _apiClient.post(
    '/users/me/fcm-token',
    {'fcmToken': fcmToken, 'ringCapable': !kIsWeb},
  );
}

final pushTokenRepositoryProvider = Provider<PushTokenRepository>(
  (ref) => PushTokenRepository(ref.watch(apiClientProvider)),
);
