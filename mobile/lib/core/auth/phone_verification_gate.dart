import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/onboarding/onboarding_controller.dart';
import '../../features/onboarding/screens/otp_verification_screen.dart';
import '../../l10n/app_localizations.dart';
import '../models/user_role.dart';
import 'session_storage.dart';

// What the user was about to do when asked to confirm their number — only
// changes the wording of the explanation dialog.
enum PhoneCheckReason { serviceRequest, mission }

// A client registers without OTP (no ID document either). The three actions
// that put them in touch with a craftsman — "Demander maintenant", posting a
// mission, applying to one — need a confirmed number (the backend enforces
// it too, see assert-phone-verified.ts), so the first time they try one of
// them this explains why, sends the code, and confirms it. That happens
// exactly once: POST /auth/otp/check marks the account verified for good
// and the new session is kept for a year (TokensService).
//
// Returns true when the caller can go ahead — straight away if the number
// is already confirmed (always the case for a craftsman), otherwise once the
// code checks out. False if they cancelled.
Future<bool> ensurePhoneVerified(
  BuildContext context,
  WidgetRef ref,
  PhoneCheckReason reason,
) async {
  final storage = ref.read(sessionStorageProvider);
  if (await storage.loadPhoneVerified()) return true;
  final phone = await storage.loadPhone();
  final role = await storage.loadRole();
  if (phone == null || !context.mounted) return false;

  final l10n = AppLocalizations.of(context)!;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.verified_user_outlined),
      title: Text(l10n.phoneCheckTitle),
      content: Text(
        reason == PhoneCheckReason.serviceRequest
            ? l10n.phoneCheckServiceRequestMessage
            : l10n.phoneCheckMissionMessage,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.phoneCheckSendCodeButton),
        ),
      ],
    ),
  );
  if (proceed != true || !context.mounted) return false;

  // OtpVerificationScreen drives OnboardingController — point it at this
  // account's own number, so a successful check lands in setVerifiedPhone's
  // "existing account" branch (fresh verified session, flag saved).
  ref.read(onboardingControllerProvider.notifier)
    ..selectRole(role ?? UserRole.client)
    ..setPhone(phone);
  final verified = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => OtpVerificationScreen(phone: phone, popOnSuccess: true),
    ),
  );
  return verified == true;
}
