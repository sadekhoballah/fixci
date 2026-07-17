import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/screens/splash_screen.dart';

class FixCiApp extends StatelessWidget {
  const FixCiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FixCi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
