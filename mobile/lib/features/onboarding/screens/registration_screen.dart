import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/countries.dart' show Country, countries;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/media/id_card_picker.dart';
import '../../../core/models/district.dart';
import '../../../core/models/service_category.dart';
import '../../../core/models/user_role.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../client_home/screens/client_shell_screen.dart';
import '../../craftsman_home/screens/artisan_shell_screen.dart';
import '../onboarding_controller.dart';
import '../onboarding_repository.dart';
import '../onboarding_state.dart';
import 'otp_verification_screen.dart';
import 'registration_success_screen.dart';
import 'tier_selection_screen.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

const _experienceOptions = ['1-2 ans', '2-4 ans', 'Plus de 5 ans'];

// Only markets currently launched — see IntlPhoneField below. Order fixes
// the picker's display order (Côte d'Ivoire, then Liban, then Russie).
final List<Country> _allowedCountries = ['CI', 'LB', 'RU']
    .map((code) => countries.firstWhere((c) => c.code == code))
    .toList();

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit(
    BuildContext context,
    OnboardingState state,
    OnboardingController controller,
  ) async {
    if (!state.isPhoneVerified) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phone: state.phone),
        ),
      );
      return;
    }
    final succeeded = await controller.completeAfterVerification();
    if (!context.mounted || !succeeded) return;

    final latest = ref.read(onboardingControllerProvider);
    if (latest.loggedIntoExistingAccount) {
      final destination = switch (latest.role) {
        UserRole.craftsman when latest.selectedTier == null =>
          const TierSelectionScreen(),
        UserRole.craftsman => const ArtisanShellScreen(),
        _ => const ClientShellScreen(),
      };
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegistrationSuccessScreen()),
    );
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
                controller: _firstNameController,
                onChanged: controller.setFirstName,
                decoration: const InputDecoration(
                  labelText: 'Prénom (comme sur votre pièce d\'identité)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                onChanged: controller.setLastName,
                decoration: const InputDecoration(
                  labelText: 'Nom de famille (comme sur votre pièce d\'identité)',
                ),
              ),
              const SizedBox(height: 16),
              IntlPhoneField(
                initialCountryCode: 'CI',
                countries: _allowedCountries,
                onChanged: (phoneNumber) =>
                    controller.setPhone(phoneNumber.completeNumber),
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                ),
              ),
              const SizedBox(height: 16),
              _DistrictPicker(state: state, controller: controller),
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
                DropdownButtonFormField<String>(
                  initialValue: state.experienceDetails.isEmpty
                      ? null
                      : state.experienceDetails,
                  decoration: const InputDecoration(labelText: 'Expérience'),
                  items: _experienceOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) controller.setExperienceDetails(value);
                  },
                ),
              ],
              const SizedBox(height: 16),
              _IdCardPicker(state: state, controller: controller),
              if (state.submissionError != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.submissionError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse('https://fix-pro.app/privacy/');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  child: Text.rich(
                    TextSpan(
                      text: 'En vous inscrivant, vous acceptez notre ',
                      children: [
                        TextSpan(
                          text: 'politique de confidentialité',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              PrimaryButton(
                label: state.isSubmitting ? 'Inscription...' : "S'inscrire",
                onPressed:
                    state.isRegistrationComplete && !state.isSubmitting
                    ? () => _submit(context, state, controller)
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

class _DistrictPicker extends ConsumerWidget {
  const _DistrictPicker({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final districtsAsync = ref.watch(districtsProvider);
    final isCraftsman = state.role == UserRole.craftsman;

    return districtsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text(
        'Impossible de charger la liste des zones.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (districts) => DropdownButtonFormField<District>(
        initialValue: state.district,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Votre zone / commune'),
        items: districts
            .map(
              (d) => DropdownMenuItem(
                value: d,
                child: Text(
                  (isCraftsman
                          ? d.isArtisanRegistrationActive
                          : d.isClientOrderingActive)
                      ? d.name
                      : '${d.name} (liste d\'attente)',
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) controller.setDistrict(value);
        },
      ),
    );
  }
}

class _IdCardPicker extends StatelessWidget {
  const _IdCardPicker({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  Future<void> _showSourceSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (idCardCameraSupported)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.pickIdCardFromCamera();
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.pickIdCardFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final attached = state.idCardAttached;
    final uploading = state.isUploadingIdCard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: uploading ? null : () => _showSourceSheet(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (attached && state.idCardPreviewBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      state.idCardPreviewBytes!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (uploading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.badge_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    uploading
                        ? 'Envoi en cours...'
                        : attached
                        ? "Pièce d'identité ajoutée"
                        : "Ajouter votre pièce d'identité",
                  ),
                ),
                if (attached && !uploading)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
          ),
        ),
        if (state.idCardUploadError != null) ...[
          const SizedBox(height: 8),
          Text(
            state.idCardUploadError!,
            style: TextStyle(color: colorScheme.error, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
