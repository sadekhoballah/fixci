import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Holds the JWT access/refresh pair issued by POST /auth/reconnect or
// POST /users/register (see backend/src/auth/tokens.service.ts) — this is
// this app's entire notion of "am I logged in". Both tokens live in the
// platform keystore, same as the phone number in SessionStorage.
class TokenStorage {
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  static const _secureStorage = FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> loadAccessToken() => _secureStorage.read(key: _accessTokenKey);

  Future<String?> loadRefreshToken() =>
      _secureStorage.read(key: _refreshTokenKey);

  // Splash screen's "do I even have a session worth checking" gate — the
  // refresh token is the longer-lived of the two, so its presence is what
  // decides that, not the (possibly already-expired) access token.
  Future<bool> hasSession() async => await loadRefreshToken() != null;

  Future<void> clear() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
