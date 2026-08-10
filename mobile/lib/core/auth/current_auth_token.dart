import 'token_storage.dart';

// This app's bearer credential everywhere a caller must prove who they are
// — both the REST client (api_client.dart) and the realtime socket
// (matching_socket_service.dart) resolve it the same way, so this lives in
// one place rather than two. Unlike the old Firebase-backed version, this
// can return an *expired* token (nothing here checks the JWT's own exp
// claim) — ApiClient/MatchingSocketService are what react to a resulting
// 401 by refreshing and retrying, not this function.
Future<String?> currentAuthToken() => TokenStorage().loadAccessToken();
