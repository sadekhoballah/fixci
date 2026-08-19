import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/session_storage.dart';
import '../network/api_client.dart';
import 'user_role.dart';

// The signed-in user's own country — derived from their account's district
// (set once at registration, see District.countryCode), not re-parsed from
// their phone number. Backs the Missions board's district picker (see
// MissionsBoardScreen), which otherwise lists every country's districts in
// one flat list. Hits whichever "me" endpoint matches the cached role since
// there's no role-agnostic one; null (picker falls back to showing every
// district, never a dead end) if the role isn't cached yet or the call
// fails for any reason.
final currentUserCountryCodeProvider = FutureProvider<String?>((ref) async {
  final role = await ref.watch(sessionStorageProvider).loadRole();
  if (role == null) return null;
  final apiClient = ref.watch(apiClientProvider);
  final path = role == UserRole.craftsman ? '/craftsmen/me' : '/clients/me';
  try {
    final response = await apiClient.get(path);
    return response['countryCode'] as String?;
  } catch (_) {
    return null;
  }
});
