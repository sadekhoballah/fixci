import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/verify_service.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_controller.dart';
import 'otp_state.dart';

// The backend replies to /auth/otp/* with a small set of exact English
// messages (OtpThrottleService.OTP_THROTTLE_MESSAGE and OtpController's
// CHECK_ERROR_MESSAGE) — mapped here to this app's localized copy rather
// than shown raw. Anything unrecognised (network text, unexpected backend
// strings) falls back to a generic verification error.
String _mapOtpError(String backendMessage, AppLocalizations l10n) {
  return switch (backendMessage) {
    'Incorrect code' => l10n.invalidCodeMessage,
    'Code expired or not found — request a new one' => l10n.codeExpiredMessage,
    'Too many incorrect attempts — request a new code' =>
      l10n.tooManyAttemptsMessage,
    'Too many attempts — try again in 24 hours' => l10n.otpBlockedForDayMessage,
    'Too many attempts — try again in a few minutes' =>
      l10n.otpBlockedTemporarilyMessage,
    'Please wait before requesting another code' => l10n.otpCooldownMessage,
    'Too many codes requested — try again later' => l10n.otpTooManyCodesMessage,
    'This phone number cannot be used' => l10n.otpPhoneNotAllowedMessage,
    'Invalid phone number' => l10n.invalidPhoneNumberMessage,
    _ => l10n.verificationErrorMessage,
  };
}

class OtpController extends Notifier<OtpState> {
  static const resendCooldown = Duration(seconds: 60);

  @override
  OtpState build() => const OtpState();

  Future<void> sendCode(
    String phoneNumber, {
    String channel = 'whatsapp',
  }) async {
    state = state.copyWith(
      isSendingCode: true,
      channel: channel,
      clearCodeSendError: true,
      clearCodeVerifyError: true,
    );
    final l10n = ref.read(l10nProvider);
    try {
      final usedChannel = await ref
          .read(verifyServiceProvider)
          .startOtp(phoneNumber, channel: channel);
      state = state.copyWith(
        isSendingCode: false,
        codeWasSent: true,
        channel: usedChannel,
        resendAvailableAt: DateTime.now().add(resendCooldown),
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isSendingCode: false,
        codeSendError: _mapOtpError(e.message, l10n),
      );
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
          .read(verifyServiceProvider)
          .checkOtp(phoneNumber, smsCode);
      state = state.copyWith(isVerifyingCode: false);
      await ref
          .read(onboardingControllerProvider.notifier)
          .setVerifiedPhone(phone: phoneNumber, outcome: outcome);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isVerifyingCode: false,
        codeVerifyError: _mapOtpError(e.message, l10n),
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
