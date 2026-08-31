// Pilot / Play-Store-review test numbers, listed in OTP_TEST_PHONES (comma-
// separated E.164, exactly as the mobile app sends them). These numbers:
//   - skip Twilio Verify entirely — no SMS/WhatsApp is sent and they verify
//     against OTP_TEST_CODE (see TwilioVerifyService);
//   - are exempt from the otherwise-mandatory ID-document upload at
//     registration, so a store reviewer can create a working artisan or
//     client account with no CNI/passport at all (see RegisterUserDto).
// It is an explicit allowlist, so it stays safe with NODE_ENV=production and
// real Twilio credentials — only these exact numbers get the shortcut.
// Clear OTP_TEST_PHONES once the review / pilot is over.
const DEFAULT_TEST_CODE = '000000';

export function otpTestPhones(): Set<string> {
  return new Set(
    (process.env.OTP_TEST_PHONES ?? '')
      .split(',')
      .map((p) => p.trim())
      .filter(Boolean),
  );
}

export function isOtpTestPhone(phone: string | null | undefined): boolean {
  return phone != null && otpTestPhones().has(phone);
}

export function otpTestCode(): string {
  return process.env.OTP_TEST_CODE || DEFAULT_TEST_CODE;
}
