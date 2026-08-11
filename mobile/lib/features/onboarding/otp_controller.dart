import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/otp_auth_service.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_controller.dart';
import 'otp_state.dart';

// POST /auth/verify-otp (see backend/src/auth/otp.controller.ts) always
// fails with one of these three exact English messages — mapped to this
// app's own localized copy rather than shown raw, since this is the one
// error a user is likely to hit repeatedly (a mistyped/expired code).
// Anything else (network errors, unexpected backend text) falls back to
// e.message as-is.
String _verifyErrorMessage(String backendMessage, AppLocalizations l10n) {
  return switch (backendMessage) {
    'Incorrect code' => l10n.invalidCodeMessage,
    'Code expired or not found — request a new one' => l10n.codeExpiredMessage,
    'Too many incorrect attempts — request a new code' =>
      l10n.tooManyAttemptsMessage,
    _ => backendMessage,
  };
}

class OtpController extends Notifier<OtpState> {
  static const resendCooldown = Duration(seconds: 45);

  @override
  OtpState build() => const OtpState();

  Future<void> sendCode(String phoneNumber) async {
    state = state.copyWith(isSendingCode: true, clearCodeSendError: true);
    final l10n = ref.read(l10nProvider);
    try {
      await ref.read(otpAuthServiceProvider).sendOtp(phoneNumber);
      state = state.copyWith(
        isSendingCode: false,
        codeWasSent: true,
        resendAvailableAt: DateTime.now().add(resendCooldown),
      );
    } on ApiException catch (e) {
      state = state.copyWith(isSendingCode: false, codeSendError: e.message);
    } catch (_) {
      state = state.copyWith(
        isSendingCode: false,
        codeSendError: l10n.genericErrorMessage,
      );
    }
  }

  Future<bool> confirmCode(String phoneNumber, String smsCode) async {
    state = state.copyWith(isVerifyingCode: true, clearCodeVerifyError: true);
    final l10n = ref.read(l10nProvider);
    try {
      final outcome = await ref
          .read(otpAuthServiceProvider)
          .verifyOtp(phoneNumber, smsCode);
      state = state.copyWith(isVerifyingCode: false);
      await ref
          .read(onboardingControllerProvider.notifier)
          .setVerifiedPhone(phone: phoneNumber, outcome: outcome);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isVerifyingCode: false,
        codeVerifyError: _verifyErrorMessage(e.message, l10n),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isVerifyingCode: false,
        codeVerifyError: l10n.genericErrorMessage,
      );
      return false;
    }
  }
}

final otpControllerProvider = NotifierProvider<OtpController, OtpState>(
  OtpController.new,
);
