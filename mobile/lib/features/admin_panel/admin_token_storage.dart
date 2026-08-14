import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Separate from mobile's SessionStorage on purpose — that one caches
// client/craftsman session state (role, tier, phone); this holds the admin
// dashboard's own JWT from POST /admin-auth/login, a completely different
// auth mechanism.
class AdminTokenStorage {
  static const _tokenKey = 'admin_jwt';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

final adminTokenStorageProvider = Provider<AdminTokenStorage>(
  (ref) => AdminTokenStorage(),
);
