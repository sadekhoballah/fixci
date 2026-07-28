import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/admin_panel/admin_auth_controller.dart';
import 'features/admin_panel/screens/admin_login_screen.dart';
import 'features/admin_panel/screens/admin_shell_screen.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fix Pro — Administration',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AdminRoot(),
    );
  }
}

class _AdminRoot extends ConsumerWidget {
  const _AdminRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      adminAuthControllerProvider.select((s) => s.status),
    );
    return switch (status) {
      AdminAuthStatus.checking => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      AdminAuthStatus.loggedOut => const AdminLoginScreen(),
      AdminAuthStatus.loggedIn => const AdminShellScreen(),
    };
  }
}
