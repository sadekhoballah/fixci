import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_category.dart';
import '../../../core/models/user_role.dart';
import '../../../shared/widgets/primary_button.dart';
import '../onboarding_controller.dart';
import 'registration_success_screen.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _experienceController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final isCraftsman = state.role == UserRole.craftsman;

    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCraftsman ? 'Votre profil artisan' : 'Vos informations',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _fullNameController,
                onChanged: controller.setFullName,
                decoration: const InputDecoration(labelText: 'Nom complet'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                onChanged: controller.setPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                ),
              ),
              if (isCraftsman) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<ServiceCategory>(
                  initialValue: state.serviceCategory,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie de service',
                  ),
                  items: ServiceCategory.values
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c, child: Text(c.label)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) controller.setServiceCategory(value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _experienceController,
                  onChanged: controller.setExperienceDetails,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Expérience (facultatif)',
                    hintText: "Ex : 5 ans d'expérience en plomberie",
                  ),
                ),
                const SizedBox(height: 16),
                _IdCardPicker(
                  attached: state.idCardAttached,
                  onTap: controller.toggleIdCardAttached,
                ),
              ],
              const SizedBox(height: 32),
              PrimaryButton(
                label: "S'inscrire",
                onPressed: state.isRegistrationComplete
                    ? () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const RegistrationSuccessScreen(),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdCardPicker extends StatelessWidget {
  const _IdCardPicker({required this.attached, required this.onTap});

  final bool attached;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              attached ? Icons.check_circle : Icons.badge_outlined,
              color: attached ? Colors.green : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                attached
                    ? "Pièce d'identité ajoutée"
                    : "Ajouter votre pièce d'identité",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
