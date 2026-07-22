import 'package:firebase_auth/firebase_auth.dart';
import '../platform/firebase_support.dart';

// The Firebase ID token doubles as this app's bearer credential everywhere
// a caller must prove who they are — both the REST client (api_client.dart)
// and the realtime socket (matching_socket_service.dart) resolve it the
// same way, so this lives in one place rather than two. The SDK caches and
// auto-refreshes the token, so fetching it fresh on every use is cheap and
// never goes stale.
Future<String?> currentAuthToken() async {
  if (!isFirebaseSupportedPlatform) return null;
  await firebaseInitFuture;
  return FirebaseAuth.instance.currentUser?.getIdToken();
}
