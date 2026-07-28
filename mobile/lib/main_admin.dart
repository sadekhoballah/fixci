import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_app.dart';

// Separate entry point from main.dart, built independently:
//   flutter build web --target=lib/main_admin.dart --base-href=/admin-panel/
// Deployed as a static bundle alongside (not instead of) the client/craftsman
// app — see mobile/deploy_admin.sh. Does not touch main.dart/app.dart, and
// has no Firebase dependency: admin auth is username/password + JWT against
// POST /admin-auth/login, unrelated to the phone-OTP flow the rest of the
// app uses.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AdminApp()));
}
