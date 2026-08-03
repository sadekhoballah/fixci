import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/countries.dart' show Country, countries;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/media/id_card_picker.dart';
import '../../../core/models/district.dart';
import '../../../core/models/service_category.dart';
import '../../../core/models/user_role.dart';
import '../../../l10n/app_localizations.dart';
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

// The actual wire value sent to the backend (craftsman_profiles.experience_details
// is a free-text column, register-user.dto.ts's experienceDetails) — kept
// stable across locales so admin.service.ts's display and existing stored
// rows don't end up a mix of languages depending on which locale a craftsman
// registered under. Display text is looked up separately per locale below.
const _experienceValues = ['1-2 ans', '2-4 ans', 'Plus de 5 ans'];

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
    final l10n = AppLocalizations.of(context)!;
    final experienceLabels = {
      '1-2 ans': l10n.experience1To2Years,
      '2-4 ans': l10n.experience2To4Years,
      'Plus de 5 ans': l10n.experienceMoreThan5Years,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.registrationTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCraftsman
                    ? l10n.registrationCraftsmanHeading
                    : l10n.registrationClientHeading,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _firstNameController,
                onChanged: controller.setFirstName,
                decoration: InputDecoration(labelText: l10n.firstNameLabel),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                onChanged: controller.setLastName,
                decoration: InputDecoration(labelText: l10n.lastNameLabel),
              ),
              const SizedBox(height: 16),
              IntlPhoneField(
                initialCountryCode: 'CI',
                countries: _allowedCountries,
                onChanged: (phoneNumber) =>
                    controller.setPhone(phoneNumber.completeNumber),
                onCountryChanged: (country) =>
                    controller.setPhoneCountryCode(country.code),
                decoration: InputDecoration(labelText: l10n.phoneNumberLabel),
              ),
              const SizedBox(height: 16),
              _DistrictPicker(state: state, controller: controller),
              if (isCraftsman) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<ServiceCategory>(
                  initialValue: state.serviceCategory,
                  decoration: InputDecoration(
                    labelText: l10n.serviceCategoryLabel,
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
                  decoration: InputDecoration(labelText: l10n.experienceLabel),
                  items: _experienceValues
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(experienceLabels[e]!),
                        ),
                      )
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
                      text: l10n.registrationPrivacyPrefix,
                      children: [
                        TextSpan(
                          text: l10n.privacyPolicyLinkText,
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
                label: state.isSubmitting
                    ? l10n.submittingButton
                    : l10n.submitButton,
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
    final l10n = AppLocalizations.of(context)!;

    // No districts are seeded for this market yet (see the migration that
    // added country_code to districts) — show why the form can't proceed
    // instead of an empty/broken-looking dropdown.
    if (!state.isCountryLaunched) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(l10n.countryComingSoonMessage),
      );
    }

    final districtsAsync = ref.watch(districtsProvider);
    final isCraftsman = state.role == UserRole.craftsman;

    return districtsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text(
        l10n.districtLoadError,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (districts) {
        final countryDistricts = districts
            .where((d) => d.countryCode == state.phoneCountryCode)
            .toList();
        return DropdownButtonFormField<District>(
          initialValue: countryDistricts.contains(state.district)
              ? state.district
              : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.districtLabel),
          items: countryDistricts
              .map(
                (d) => DropdownMenuItem(
                  value: d,
                  child: Text(
                    (isCraftsman
                            ? d.isArtisanRegistrationActive
                            : d.isClientOrderingActive)
                        ? d.name
                        : l10n.districtWaitlistSuffix(d.name),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) controller.setDistrict(value);
          },
        );
      },
    );
  }
}

class _IdCardPicker extends StatelessWidget {
  const _IdCardPicker({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  Future<void> _showSourceSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (idCardCameraSupported)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.takePhotoLabel),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.pickIdCardFromCamera();
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGalleryLabel),
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
    final l10n = AppLocalizations.of(context)!;

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
                        ? l10n.idCardUploading
                        : attached
                        ? l10n.idCardAdded
                        : l10n.idCardAddPrompt,
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
