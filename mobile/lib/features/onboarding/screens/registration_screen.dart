import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/phone_hint_service.dart';
import '../../../core/media/id_card_picker.dart';
import '../../../core/models/district.dart';
import '../../../core/models/service_category.dart';
import '../../../core/models/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../client_home/screens/client_shell_screen.dart';
import '../../craftsman_home/screens/artisan_shell_screen.dart';
import '../allowed_countries.dart';
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
    // Verify the phone first: fill the form, then Twilio Verify on the OTP
    // screen, which completes registration itself once the code checks out.
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
              const _PhoneField(),
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
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.localizedLabel(l10n)),
                        ),
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
              if (isCraftsman &&
                  (state.serviceCategory?.requiresDriverLicense ??
                      false)) ...[
                const SizedBox(height: 16),
                _LicensePicker(state: state, controller: controller),
              ],
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

// Android: on first focus, launches the Phone Number Hint API and locks the
// field to whatever the user picks — they can no longer type into it, only
// re-open the system picker (tap the field, or the "Modifier" action) to
// pick the device's other SIM. A null result (no numbers on the device, or
// the picker was dismissed — Android doesn't tell us which) leaves the
// field as a normal editable one, which is also exactly what iOS gets from
// the start (see PhoneHintService.isSupported).
class _PhoneField extends ConsumerStatefulWidget {
  const _PhoneField();

  @override
  ConsumerState<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends ConsumerState<_PhoneField> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _autoHintTriggered = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  // "When the user reaches the phone number field" — approximated as "the
  // first time it gains focus", since it sits inline in a larger scrolling
  // form rather than behind its own navigation step.
  void _onFocusChange() {
    if (!_focusNode.hasFocus || _autoHintTriggered) return;
    final state = ref.read(onboardingControllerProvider);
    if (state.phoneLocked || !ref.read(phoneHintServiceProvider).isSupported) {
      return;
    }
    _autoHintTriggered = true;
    ref.read(onboardingControllerProvider.notifier).requestPhoneHint();
  }

  void _reopenPicker() {
    ref.read(onboardingControllerProvider.notifier).requestPhoneHint();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    if (state.phoneLocked) {
      final parsed = parsePhoneHint(
        state.phone,
        allowedCountries: allowedCountries,
        currentCountryIsoCode: state.phoneCountryCode,
      );
      if (_textController.text != parsed.localNumber) {
        _textController.text = parsed.localNumber;
      }
    }

    final field = IntlPhoneField(
      // initialCountryCode is only read once, at construction — changing
      // the key forces a fresh instance so a hint-resolved country actually
      // updates the displayed flag.
      key: ValueKey('phone-${state.phoneCountryCode}'),
      controller: _textController,
      focusNode: _focusNode,
      initialCountryCode: state.phoneCountryCode,
      countries: allowedCountries,
      readOnly: state.phoneLocked,
      onChanged: state.phoneLocked
          ? null
          : (phoneNumber) => ref
                .read(onboardingControllerProvider.notifier)
                .setPhone(phoneNumber.completeNumber),
      onCountryChanged: state.phoneLocked
          ? null
          : (country) => ref
                .read(onboardingControllerProvider.notifier)
                .setPhoneCountryCode(country.code),
      decoration: InputDecoration(
        labelText: l10n.phoneNumberLabel,
        suffixIcon: state.isRequestingPhoneHint
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : state.phoneLocked
            ? TextButton(
                onPressed: _reopenPicker,
                child: Text(l10n.phoneChangeAction),
              )
            : null,
      ),
    );

    if (!state.phoneLocked) return field;

    // AbsorbPointer, not just readOnly/enabled: readOnly alone still lets
    // IntlPhoneField's own flag icon open its internal country-picker
    // dialog (a separate tap target from the text field itself), which
    // would let the country be changed manually — not allowed once locked.
    // Wrapping the whole field means every tap, wherever it lands, does the
    // one thing a locked field should do: re-open the device's own picker.
    return GestureDetector(
      onTap: _reopenPicker,
      child: AbsorbPointer(child: field),
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

// Second mandatory document, only rendered for taxi/camion — see the
// requiresDriverLicense check in RegistrationScreen.build. Structurally
// identical to _IdCardPicker above, just pointed at the license fields.
class _LicensePicker extends StatelessWidget {
  const _LicensePicker({required this.state, required this.controller});

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
                  controller.pickLicenseFromCamera();
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGalleryLabel),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.pickLicenseFromGallery();
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
    final attached = state.licenseAttached;
    final uploading = state.isUploadingLicense;
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
                if (attached && state.licensePreviewBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      state.licensePreviewBytes!,
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
                        ? l10n.licenseUploading
                        : attached
                        ? l10n.licenseAdded
                        : l10n.licenseAddPrompt,
                  ),
                ),
                if (attached && !uploading)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
          ),
        ),
        if (state.licenseUploadError != null) ...[
          const SizedBox(height: 8),
          Text(
            state.licenseUploadError!,
            style: TextStyle(color: colorScheme.error, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
