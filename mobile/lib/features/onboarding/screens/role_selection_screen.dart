import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_role.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/role_card.dart';
import '../onboarding_controller.dart';
import 'registration_screen.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                'Qui êtes-vous ?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Choisissez comment vous voulez utiliser FixCi',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              RoleCard(
                icon: Icons.person_search_rounded,
                title: UserRole.client.label,
                subtitle: UserRole.client.description,
                selected: state.role == UserRole.client,
                onTap: () => controller.selectRole(UserRole.client),
                illustrationAsset: 'assets/role_icons/client.png',
              ),
              const SizedBox(height: 16),
              RoleCard(
                icon: Icons.handyman_rounded,
                title: UserRole.craftsman.label,
                subtitle: UserRole.craftsman.description,
                selected: state.role == UserRole.craftsman,
                onTap: () => controller.selectRole(UserRole.craftsman),
                illustrationAsset: 'assets/role_icons/artisan.png',
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continuer',
                onPressed: state.role == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegistrationScreen(),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
