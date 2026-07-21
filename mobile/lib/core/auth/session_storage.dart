import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_tier.dart';
import '../models/user_role.dart';

class SessionStorage {
  static const _roleKey = 'session_role';
  static const _tierKey = 'session_tier';

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
}

final sessionStorageProvider = Provider<SessionStorage>((ref) => SessionStorage());
