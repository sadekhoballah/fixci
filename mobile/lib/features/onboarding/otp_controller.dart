import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/phone_verification_provider.dart';
import '../../core/auth/phone_verification_service.dart';
import '../../core/localization/locale_controller.dart';
import 'onboarding_controller.dart';
import 'otp_state.dart';

class OtpController extends Notifier<OtpState> {
  static const resendCooldown = Duration(seconds: 45);

  @override
  OtpState build() => const OtpState();

  Future<void> sendCode(String phoneNumber) async {
    state = state.copyWith(isSendingCode: true, clearCodeSendError: true);
    final l10n = ref.read(l10nProvider);
    try {
      await ref
          .read(phoneVerificationServiceProvider)
          .sendCode(
            phoneNumber: phoneNumber,
            onCodeSent: (result) {
              state = state.copyWith(
                isSendingCode: false,
                verificationId: result.verificationId,
                resendAvailableAt: DateTime.now().add(resendCooldown),
              );
            },
            onAutoVerified: (idToken) {
              state = state.copyWith(isSendingCode: false);
              ref
                  .read(onboardingControllerProvider.notifier)
                  .setVerifiedPhone(phone: phoneNumber, idToken: idToken);
            },
            onFailed: (error) {
              state = state.copyWith(
                isSendingCode: false,
                // TEMP DIAGNOSTIC: appends the raw Firebase code/message so
                // it's visible on screen. Remove with debugDetail once the
                // phone-auth root cause is found.
                codeSendError: _withDebugDetail(
                  error.error.localizedMessage(l10n),
                  error.debugDetail,
                ),
              );
            },
          );
    } on PhoneVerificationException catch (e) {
      state = state.copyWith(
        isSendingCode: false,
        codeSendError: _withDebugDetail(
          e.error.localizedMessage(l10n),
          e.debugDetail,
        ),
      );
    } catch (_) {
      state = state.copyWith(
        isSendingCode: false,
        codeSendError: l10n.genericErrorMessage,
      );
    }
  }

  Future<bool> confirmCode(String phoneNumber, String smsCode) async {
    final verificationId = state.verificationId;
    if (verificationId == null) return false;

    state = state.copyWith(isVerifyingCode: true, clearCodeVerifyError: true);
    final l10n = ref.read(l10nProvider);
    try {
      final idToken = await ref
          .read(phoneVerificationServiceProvider)
          .confirmCode(verificationId: verificationId, smsCode: smsCode);
      state = state.copyWith(isVerifyingCode: false);
      ref
          .read(onboardingControllerProvider.notifier)
          .setVerifiedPhone(phone: phoneNumber, idToken: idToken);
      return true;
    } on PhoneVerificationException catch (e) {
      state = state.copyWith(
        isVerifyingCode: false,
        codeVerifyError: _withDebugDetail(
          e.error.localizedMessage(l10n),
          e.debugDetail,
        ),
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

// TEMP DIAGNOSTIC: appends the raw Firebase code/message to the localized
// error text so it's visible on screen. Remove once the phone-auth root
// cause is found (see PhoneVerificationException.debugDetail).
String _withDebugDetail(String message, String? debugDetail) {
  if (debugDetail == null) return message;
  return '$message\n$debugDetail';
}
