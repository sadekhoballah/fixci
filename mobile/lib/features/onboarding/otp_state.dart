class OtpState {
  const OtpState({
    this.channel = 'sms',
    this.codeWasSent = false,
    this.isSendingCode = false,
    this.isVerifyingCode = false,
    this.codeSendError,
    this.codeVerifyError,
    this.resendAvailableAt,
  });

  // The channel the last code was actually sent on ('whatsapp' or 'sms') —
  // drives the notice text and which fallback the resend button offers.
  final String channel;
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
    String? channel,
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
      channel: channel ?? this.channel,
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
