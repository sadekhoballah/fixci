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
                codeSendError: error.error.localizedMessage(l10n),
              );
            },
          );
    } on PhoneVerificationException catch (e) {
      state = state.copyWith(
        isSendingCode: false,
        codeSendError: e.error.localizedMessage(l10n),
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
        codeVerifyError: e.error.localizedMessage(l10n),
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
