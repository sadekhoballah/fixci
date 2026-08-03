import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../client_home/screens/client_shell_screen.dart';
import '../onboarding_controller.dart';
import 'tier_selection_screen.dart';

class RegistrationSuccessScreen extends ConsumerWidget {
  const RegistrationSuccessScreen({super.key});

  void _continue(BuildContext context, UserRole? role) {
    final destination = role == UserRole.craftsman
        ? const TierSelectionScreen()
        : const ClientShellScreen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final l10n = AppLocalizations.of(context)!;
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
                l10n.welcomeMessage(state.fullName),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.accountCreatedMessage,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PrimaryButton(
                label: l10n.continueButton,
                onPressed: () => _continue(context, state.role),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
