import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/dev_bypass_session.dart';
import '../../../core/auth/session_storage.dart';
import '../../../core/auth/user_lookup_service.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../core/models/user_role.dart';
import '../../../core/platform/firebase_support.dart';
import '../../client_home/screens/client_home_screen.dart';
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
      storage.loadPhone(),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);
    if (!mounted) return;

    var role = results[0] as UserRole?;
    final tier = results[1] as SubscriptionTier?;
    final phone = results[2] as String?;

    if (role != null && !await _stillRegistered(phone)) {
      await storage.clearSession();
      role = null;
    }
    if (!mounted) return;

    final destination = switch (role) {
      UserRole.client => const ClientHomeScreen(),
      UserRole.craftsman => tier == null
          ? const TierSelectionScreen()
          : const ArtisanShellScreen(),
      null => const RoleSelectionScreen(),
    };
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  // The lookup call authenticates with the current Firebase session — no
  // session means we can't ask the backend anything (e.g. the user was
  // signed out), so treat that the same as "not registered" rather than
  // trusting the cached role forever. On platforms with no real Firebase
  // session at all (the desktop dev-bypass), fall back to the same
  // X-Dev-Phone mechanism the rest of the app uses there — see
  // devBypassPhone.
  Future<bool> _stillRegistered(String? phone) async {
    if (isFirebaseSupportedPlatform) {
      if (FirebaseAuth.instance.currentUser == null) return false;
      return ref.read(userLookupServiceProvider).isPhoneStillRegistered();
    }
    if (phone == null) return false;
    devBypassPhone = phone;
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
