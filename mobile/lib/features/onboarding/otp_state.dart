class OtpState {
  const OtpState({
    this.verificationId,
    this.isSendingCode = false,
    this.isVerifyingCode = false,
    this.codeSendError,
    this.codeVerifyError,
    this.resendAvailableAt,
  });

  final String? verificationId;
  final bool isSendingCode;
  final bool isVerifyingCode;
  final String? codeSendError;
  final String? codeVerifyError;
  final DateTime? resendAvailableAt;

  bool get codeWasSent => verificationId != null;

  bool get canResend =>
      resendAvailableAt == null || DateTime.now().isAfter(resendAvailableAt!);

  Duration get resendCooldownRemaining {
    if (resendAvailableAt == null) return Duration.zero;
    final remaining = resendAvailableAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  OtpState copyWith({
    String? verificationId,
    bool? isSendingCode,
    bool? isVerifyingCode,
    String? codeSendError,
    bool clearCodeSendError = false,
    String? codeVerifyError,
    bool clearCodeVerifyError = false,
    DateTime? resendAvailableAt,
  }) {
    return OtpState(
      verificationId: verificationId ?? this.verificationId,
      isSendingCode: isSendingCode ?? this.isSendingCode,
      isVerifyingCode: isVerifyingCode ?? this.isVerifyingCode,
      codeSendError: clearCodeSendError
          ? null
          : (codeSendError ?? this.codeSendError),
      codeVerifyError: clearCodeVerifyError
          ? null
          : (codeVerifyError ?? this.codeVerifyError),
      resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
    );
  }
}
