class OtpState {
  const OtpState({
    this.codeWasSent = false,
    this.isSendingCode = false,
    this.isVerifyingCode = false,
    this.codeSendError,
    this.codeVerifyError,
    this.resendAvailableAt,
  });

  final bool codeWasSent;
  final bool isSendingCode;
  final bool isVerifyingCode;
  final String? codeSendError;
  final String? codeVerifyError;
  final DateTime? resendAvailableAt;

  bool get canResend =>
      resendAvailableAt == null || DateTime.now().isAfter(resendAvailableAt!);

  Duration get resendCooldownRemaining {
    if (resendAvailableAt == null) return Duration.zero;
    final remaining = resendAvailableAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  OtpState copyWith({
    bool? codeWasSent,
    bool? isSendingCode,
    bool? isVerifyingCode,
    String? codeSendError,
    bool clearCodeSendError = false,
    String? codeVerifyError,
    bool clearCodeVerifyError = false,
    DateTime? resendAvailableAt,
  }) {
    return OtpState(
      codeWasSent: codeWasSent ?? this.codeWasSent,
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
