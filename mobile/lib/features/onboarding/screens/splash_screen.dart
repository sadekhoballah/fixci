import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/session_storage.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/auth/user_lookup_service.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../core/models/user_role.dart';
import '../../client_home/screens/client_shell_screen.dart';
import '../../craftsman_home/screens/artisan_shell_screen.dart';
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
    final storage = ref.read(sessionStorageProvider);
    final results = await Future.wait([
      storage.loadRole(),
      storage.loadTier(),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);
    if (!mounted) return;

    var role = results[0] as UserRole?;
    final tier = results[1] as SubscriptionTier?;

    if (role != null && !await _stillRegistered()) {
      await storage.clearSession();
      await ref.read(tokenStorageProvider).clear();
      role = null;
    }
    if (!mounted) return;

    final destination = switch (role) {
      UserRole.client => const ClientShellScreen(),
      UserRole.craftsman => tier == null
          ? const TierSelectionScreen()
          : const ArtisanShellScreen(),
      null => const RoleSelectionScreen(),
    };
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  // No stored access/refresh token pair at all means there's no session to
  // even attempt — ApiClient's own refresh-on-401 handles a merely *expired*
  // access token transparently, so this only needs to rule out "never
  // logged in" / "logged out" before bothering the backend.
  Future<bool> _stillRegistered() async {
    if (!await ref.read(tokenStorageProvider).hasSession()) return false;
    return ref.read(userLookupServiceProvider).isPhoneStillRegistered();
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
