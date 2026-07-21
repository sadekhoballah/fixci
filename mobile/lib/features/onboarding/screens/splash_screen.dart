import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/session_storage.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../core/models/user_role.dart';
import '../../client_home/screens/client_home_screen.dart';
import '../../craftsman_home/screens/craftsman_dashboard_screen.dart';
import 'role_selection_screen.dart';
import 'tier_selection_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _prepareNextScreen();
  }

  Future<void> _prepareNextScreen() async {
    final results = await Future.wait([
      ref.read(sessionStorageProvider).loadRole(),
      ref.read(sessionStorageProvider).loadTier(),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);
    if (!mounted) return;
    final role = results[0] as UserRole?;
    final tier = results[1] as SubscriptionTier?;
    final destination = switch (role) {
      UserRole.client => const ClientHomeScreen(),
      UserRole.craftsman => tier == null
          ? const TierSelectionScreen()
          : const CraftsmanDashboardScreen(),
      null => const RoleSelectionScreen(),
    };
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA70804),
      body: SizedBox.expand(
        child: Image.asset('assets/splash/splash.png', fit: BoxFit.contain),
      ),
    );
  }
}
