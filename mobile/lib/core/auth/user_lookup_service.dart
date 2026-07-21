import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

class UserLookupService {
  UserLookupService(this._apiClient);

  final ApiClient _apiClient;

  // Confirms a cached local session still corresponds to a real account —
  // a role saved in SharedPreferences means nothing on its own if the
  // account was deleted server-side since the last launch. Network/server
  // errors are treated as "can't confirm" (true) rather than "not
  // registered", so a dropped connection doesn't wrongly force
  // re-registration.
  Future<bool> isPhoneStillRegistered(String phone) async {
    try {
      await _apiClient.get('/users/lookup?phone=${Uri.encodeQueryComponent(phone)}');
      return true;
    } on ApiException catch (e) {
      return e.statusCode != 404;
    }
  }
}

final userLookupServiceProvider = Provider<UserLookupService>(
  (ref) => UserLookupService(ref.watch(apiClientProvider)),
);
