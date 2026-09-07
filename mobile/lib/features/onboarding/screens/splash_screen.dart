import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/session_storage.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/auth/user_lookup_service.dart';
import '../../../core/auth/verify_service.dart';
import '../../../core/models/subscription_tier.dart';
import '../../../core/models/user_role.dart';
import '../../../core/screenshot_mode.dart';
import '../../client_home/screens/client_shell_screen.dart';
import '../../craftsman_home/screens/artisan_shell_screen.dart';
import '../onboarding_controller.dart';
import '../onboarding_repository.dart';
import 'role_selection_screen.dart';
import 'tier_selection_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  // See core/screenshot_mode.dart. In every normal build `kScreenshotMode`
  // is a const `false`, so `_screenshotLogin` and everything it reaches is
  // tree-shaken away.
  static const _screenshotPhone = String.fromEnvironment(
    'SCREENSHOT_PHONE',
    defaultValue: '+2250505050505', // Apple-review test CLIENT (OTP bypass)
  );
  static const _screenshotOtp = '000000';

  @override
  void initState() {
    super.initState();
    _prepareNextScreen();
  }

  Future<void> _prepareNextScreen() async {
    if (kScreenshotMode && await _screenshotLogin()) return;

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

  // Logs straight into the OTP-bypass test client account and jumps to its
  // home shell, so the screenshot flow (mobile/.maestro/screenshots.yaml)
  // never has to drive the onboarding form / OTP screen. Returns false to
  // fall back to the normal launch flow if anything goes wrong.
  Future<bool> _screenshotLogin() async {
    try {
      final verify = ref.read(verifyServiceProvider);
      final onboarding = ref.read(onboardingControllerProvider.notifier);

      await verify.startOtp(_screenshotPhone, channel: 'sms');
      final outcome = await verify.checkOtp(_screenshotPhone, _screenshotOtp);
      onboarding.setPhone(_screenshotPhone);
      await onboarding.setVerifiedPhone(
        phone: _screenshotPhone,
        outcome: outcome,
      );

      if (outcome is NewUserVerified) {
        // No account for this number yet -- register a minimal client (the
        // ID document is waived backend-side for OTP-bypass numbers).
        final districts =
            await ref.read(onboardingRepositoryProvider).getDistricts();
        if (districts.isEmpty) return false;
        onboarding
          ..selectRole(UserRole.client)
          ..setFirstName('Client')
          ..setLastName('Démo')
          ..setDistrict(districts.first);
        if (!await onboarding.submitRegistration()) return false;
      }

      if (!mounted) return false;
      final role = await ref.read(sessionStorageProvider).loadRole();
      if (!mounted) return false;
      final destination = role == UserRole.craftsman
          ? const ArtisanShellScreen()
          : const ClientShellScreen();
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
      return true;
    } catch (_) {
      return false;
    }
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
