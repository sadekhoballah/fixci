import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_role.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../client_home/screens/client_home_screen.dart';
import '../../craftsman_home/screens/artisan_shell_screen.dart';
import '../onboarding_controller.dart';
import '../otp_controller.dart';
import 'registration_success_screen.dart';
import 'tier_selection_screen.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  Timer? _cooldownTicker;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    // Riverpod disallows modifying provider state synchronously during a
    // widget's initState — sendCode's first line does that, so defer to
    // after this build phase completes.
    Future.microtask(
      () => ref.read(otpControllerProvider.notifier).sendCode(widget.phone),
    );
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTicker?.cancel();
    super.dispose();
  }

  Future<void> _confirm() async {
    await ref
        .read(otpControllerProvider.notifier)
        .confirmCode(widget.phone, _codeController.text.trim());
    // On success this flips OnboardingState.isPhoneVerified, which the
    // ref.listen below reacts to by completing registration. On failure the
    // error is already reflected in OtpState and shown inline below.
  }

  Future<void> _completeRegistration() async {
    if (_completing) return;
    _completing = true;
    final notifier = ref.read(onboardingControllerProvider.notifier);
    final succeeded = await notifier.completeAfterVerification();
    if (!mounted) return;
    if (!succeeded) {
      _completing = false;
      return;
    }

    final state = ref.read(onboardingControllerProvider);
    if (state.loggedIntoExistingAccount) {
      final destination = switch (state.role) {
        UserRole.craftsman when state.selectedTier == null =>
          const TierSelectionScreen(),
        UserRole.craftsman => const ArtisanShellScreen(),
        _ => const ClientHomeScreen(),
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
    final otpState = ref.watch(otpControllerProvider);
    final onboardingState = ref.watch(onboardingControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(onboardingControllerProvider, (previous, next) {
      final justVerified =
          next.isPhoneVerified && previous?.isPhoneVerified != true;
      if (justVerified) _completeRegistration();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Vérification du numéro')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entrez le code envoyé au ${widget.phone}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              if (otpState.isSendingCode)
                const Center(child: CircularProgressIndicator())
              else if (otpState.codeSendError != null) ...[
                Text(
                  otpState.codeSendError!,
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Réessayer',
                  onPressed: () =>
                      ref.read(otpControllerProvider.notifier).sendCode(widget.phone),
                ),
              ] else if (otpState.codeWasSent || _completing) ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Code à 6 chiffres',
                    counterText: '',
                  ),
                ),
                if (otpState.codeVerifyError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    otpState.codeVerifyError!,
                    style: TextStyle(color: colorScheme.error, fontSize: 13),
                  ),
                ],
                if (onboardingState.submissionError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    onboardingState.submissionError!,
                    style: TextStyle(color: colorScheme.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: (otpState.isVerifyingCode || _completing)
                      ? 'Vérification...'
                      : 'Vérifier',
                  onPressed:
                      (otpState.isVerifyingCode ||
                          _completing ||
                          _codeController.text.trim().length != 6)
                      ? null
                      : _confirm,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: otpState.canResend
                        ? () => ref
                              .read(otpControllerProvider.notifier)
                              .sendCode(widget.phone)
                        : null,
                    child: Text(
                      otpState.canResend
                          ? 'Renvoyer le code'
                          : 'Renvoyer le code (${otpState.resendCooldownRemaining.inSeconds}s)',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
