import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/localization/locale_controller.dart';
import 'core/navigation/navigator_key.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/screens/splash_screen.dart';
import 'l10n/app_localizations.dart';

class FixCiApp extends ConsumerWidget {
  const FixCiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Fix Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SplashScreen(),
    );
  }
}
