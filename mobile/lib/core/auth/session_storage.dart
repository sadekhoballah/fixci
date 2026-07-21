import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_tier.dart';
import '../models/user_role.dart';

class SessionStorage {
  static const _roleKey = 'session_role';
  static const _tierKey = 'session_tier';
  static const _phoneKey = 'session_phone';

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phone);
  }

  Future<String?> loadPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  // Wipes the cached session — used when the backend no longer recognizes
  // this phone (e.g. the account was deleted), so the next launch goes
  // through registration instead of trusting stale local flags.
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_tierKey);
    await prefs.remove(_phoneKey);
  }
}

final sessionStorageProvider = Provider<SessionStorage>((ref) => SessionStorage());
