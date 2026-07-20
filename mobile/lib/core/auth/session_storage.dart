import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_role.dart';

class SessionStorage {
  static const _roleKey = 'session_role';

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
}

final sessionStorageProvider = Provider<SessionStorage>((ref) => SessionStorage());
