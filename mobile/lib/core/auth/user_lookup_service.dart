import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

class UserLookupService {
  UserLookupService(this._apiClient);

  final ApiClient _apiClient;

  // Confirms a cached local session still corresponds to a real account —
  // a role saved in SharedPreferences means nothing on its own if the
  // account was deleted server-side since the last launch. The backend
  // derives the phone to look up from the caller's own auth token, so this
  // can only ever check the signed-in user's own account. Network/server
  // errors are treated as "can't confirm" (true) rather than "not
  // registered", so a dropped connection doesn't wrongly force
  // re-registration.
  Future<bool> isPhoneStillRegistered() async {
    try {
      await _apiClient.get('/users/lookup');
      return true;
    } on ApiException catch (e) {
      return e.statusCode != 404 && e.statusCode != 401;
    }
  }
}

final userLookupServiceProvider = Provider<UserLookupService>(
  (ref) => UserLookupService(ref.watch(apiClientProvider)),
);
