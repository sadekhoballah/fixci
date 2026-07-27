import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

class PushTokenRepository {
  PushTokenRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> registerToken(String fcmToken) =>
      _apiClient.post('/users/me/fcm-token', {'fcmToken': fcmToken});
}

final pushTokenRepositoryProvider = Provider<PushTokenRepository>(
  (ref) => PushTokenRepository(ref.watch(apiClientProvider)),
);
