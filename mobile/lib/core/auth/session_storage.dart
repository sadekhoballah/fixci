import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_tier.dart';
import '../models/user_role.dart';

class SessionStorage {
  static const _roleKey = 'session_role';
  static const _tierKey = 'session_tier';
  static const _phoneKey = 'session_phone';
  static const _isAdminKey = 'session_is_admin';

  // The phone number is the one piece of quasi-identifying data cached
  // locally, so unlike role/tier (plain UI state) it belongs in the
  // platform keystore rather than plaintext SharedPreferences.
  static const _secureStorage = FlutterSecureStorage();

  Future<void> saveRole(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.wireValue);
  }

  Future<UserRole?> loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_roleKey)) {
      'client' => UserRole.client,
      'craftsman' => UserRole.craftsman,
      _ => null,
    };
  }

  Future<void> saveTier(SubscriptionTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tierKey, tier.wireValue);
  }

  Future<SubscriptionTier?> loadTier() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_tierKey)) {
      'free' => SubscriptionTier.free,
      'bronze' => SubscriptionTier.bronze,
      'silver' => SubscriptionTier.silver,
      'gold' => SubscriptionTier.gold,
      _ => null,
    };
  }

  Future<void> savePhone(String phone) async {
    await _secureStorage.write(key: _phoneKey, value: phone);
  }

  Future<String?> loadPhone() async {
    return _secureStorage.read(key: _phoneKey);
  }

  // Purely a UI convenience flag (show/hide the admin entry point) — every
  // actual admin endpoint re-checks the caller's phone against
  // ADMIN_PHONE_NUMBERS server-side regardless of what's cached here.
  Future<void> saveIsAdmin(bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isAdminKey, isAdmin);
  }

  Future<bool> loadIsAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isAdminKey) ?? false;
  }

  // Wipes the cached session — used when the backend no longer recognizes
  // this phone (e.g. the account was deleted), so the next launch goes
  // through registration instead of trusting stale local flags.
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_tierKey);
    await prefs.remove(_isAdminKey);
    await _secureStorage.delete(key: _phoneKey);
  }
}

final sessionStorageProvider = Provider<SessionStorage>((ref) => SessionStorage());
