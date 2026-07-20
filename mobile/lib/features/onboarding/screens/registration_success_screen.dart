import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_role.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../client_home/screens/client_home_screen.dart';
import '../../craftsman_home/screens/craftsman_dashboard_screen.dart';
import '../onboarding_controller.dart';

class RegistrationSuccessScreen extends ConsumerWidget {
  const RegistrationSuccessScreen({super.key});

  void _continue(BuildContext context, UserRole? role) {
    final destination = role == UserRole.craftsman
        ? const CraftsmanDashboardScreen()
        : const ClientHomeScreen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 72,
              ),
              const SizedBox(height: 24),
              Text(
                'Bienvenue, ${state.fullName} !',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Votre compte a été créé.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continuer',
                onPressed: () => _continue(context, state.role),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
