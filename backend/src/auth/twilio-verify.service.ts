import { BadRequestException, Injectable, Logger } from '@nestjs/common';

export type VerifyChannel = 'whatsapp' | 'sms';

export type CheckVerificationResult =
  'approved' | 'invalid' | 'expired' | 'too_many_attempts';

const VERIFY_BASE_URL = 'https://verify.twilio.com/v2';

// Twilio error codes we branch on (numeric `code` in the JSON body).
const TWILIO_INVALID_PHONE = 60200;
const TWILIO_MAX_SEND_ATTEMPTS = 60203;
const TWILIO_MAX_CHECK_ATTEMPTS = 60202;
const TWILIO_NOT_FOUND = 20404;

// Dev bypass: with no Twilio credentials configured and outside production,
// startVerification is a no-op and this fixed code always verifies — Twilio
// Verify never exposes the real code, so there's nothing to log like the
// old Redis OtpService did.
const DEV_BYPASS_CODE = '000000';

// Pilot test-phone allowlist: numbers listed in OTP_TEST_PHONES (comma-
// separated, exact E.164 as the app sends them) never touch Twilio — no SMS
// is sent and they verify against OTP_TEST_CODE (default 000000). Unlike the
// dev bypass above this is keyed to an explicit list, so it stays safe with
// NODE_ENV=production and real Twilio credentials: only those exact numbers
// skip the paid SMS. Clear OTP_TEST_PHONES once the pilot is over.
function testPhones(): Set<string> {
  return new Set(
    (process.env.OTP_TEST_PHONES ?? '')
      .split(',')
      .map((p) => p.trim())
      .filter(Boolean),
  );
}

function testCode(): string {
  return process.env.OTP_TEST_CODE || DEV_BYPASS_CODE;
}

// The one place that talks to Twilio Verify — mirrors the old
// whatsapp/whatsapp.service.ts's role of being the single outbound-OTP touch
// point, on the global `fetch` (Node 24), same idiom as the payment stub
// clients. Verify owns code generation, TTL (set on the Service in Twilio's
// console), the SMS/WhatsApp template, and its own fraud rate-limits; our
// extra lockout ladder lives in OtpThrottleService.
@Injectable()
export class TwilioVerifyService {
  private readonly logger = new Logger(TwilioVerifyService.name);

  get isConfigured(): boolean {
    return Boolean(
      process.env.TWILIO_ACCOUNT_SID &&
      process.env.TWILIO_AUTH_TOKEN &&
      process.env.TWILIO_VERIFY_SERVICE_SID,
    );
  }

  // WhatsApp is the primary channel; the mobile client only asks for 'sms'
  // as an explicit fallback. Two kill-switches, each forcing one channel and
  // ignoring what the caller asked for:
  //   TWILIO_VERIFY_WHATSAPP_ENABLED=false -> SMS only (no WhatsApp sender
  //     linked to the Verify Service).
  //   TWILIO_VERIFY_SMS_ENABLED=false -> WhatsApp only (cost trial — SMS in
  //     Côte d'Ivoire is ~10x WhatsApp; re-enable by dropping the env line).
  // WhatsApp-disabled wins if both are set.
  resolveChannel(requested: VerifyChannel | undefined): VerifyChannel {
    if (process.env.TWILIO_VERIFY_WHATSAPP_ENABLED === 'false') return 'sms';
    if (process.env.TWILIO_VERIFY_SMS_ENABLED === 'false') return 'whatsapp';
    return requested ?? 'whatsapp';
  }

  isTestPhone(phone: string): boolean {
    return testPhones().has(phone);
  }

  async startVerification(
    phone: string,
    channel: VerifyChannel,
  ): Promise<void> {
    if (this.isTestPhone(phone)) {
      this.logger.log(
        `Test phone ${phone} — skipping ${channel} send, verifies with code ${testCode()}`,
      );
      return;
    }

    if (!this.isConfigured) {
      if (process.env.NODE_ENV === 'production') {
        throw new BadRequestException('OTP delivery is not configured');
      }
      this.logger.warn(
        `Twilio not configured — skipping ${channel} send to ${phone} (dev bypass, use code ${DEV_BYPASS_CODE})`,
      );
      return;
    }

    const body = new URLSearchParams({ To: phone, Channel: channel });
    const { response, json } = await this.call('Verifications', body, phone);

    if (!response.ok) {
      if (json?.code === TWILIO_INVALID_PHONE) {
        throw new BadRequestException('Invalid phone number');
      }
      this.logger.error(
        `Twilio start-verification rejected ${phone} (${channel}): ${response.status} ${JSON.stringify(json)}`,
      );
      throw new BadRequestException('Could not send the verification code');
    }
  }

  async checkVerification(
    phone: string,
    code: string,
  ): Promise<CheckVerificationResult> {
    if (this.isTestPhone(phone)) {
      return code === testCode() ? 'approved' : 'invalid';
    }

    if (!this.isConfigured) {
      if (process.env.NODE_ENV === 'production') {
        throw new BadRequestException('OTP delivery is not configured');
      }
      return code === DEV_BYPASS_CODE ? 'approved' : 'invalid';
    }

    const body = new URLSearchParams({ To: phone, Code: code });
    const { response, json } = await this.call(
      'VerificationCheck',
      body,
      phone,
    );

    if (response.ok) {
      return json?.status === 'approved' ? 'approved' : 'invalid';
    }

    // A consumed/expired/never-sent verification 404s; hitting Twilio's own
    // per-code attempt ceiling 429s with a max-attempts code.
    if (response.status === 404 || json?.code === TWILIO_NOT_FOUND) {
      return 'expired';
    }
    if (
      json?.code === TWILIO_MAX_CHECK_ATTEMPTS ||
      json?.code === TWILIO_MAX_SEND_ATTEMPTS
    ) {
      return 'too_many_attempts';
    }
    this.logger.error(
      `Twilio check-verification failed for ${phone}: ${response.status} ${JSON.stringify(json)}`,
    );
    return 'invalid';
  }

  private async call(
    resource: 'Verifications' | 'VerificationCheck',
    body: URLSearchParams,
    phone: string,
  ): Promise<{ response: Response; json: { code?: number; status?: string } }> {
    const accountSid = process.env.TWILIO_ACCOUNT_SID!;
    const authToken = process.env.TWILIO_AUTH_TOKEN!;
    const serviceSid = process.env.TWILIO_VERIFY_SERVICE_SID!;
    const auth = Buffer.from(`${accountSid}:${authToken}`).toString('base64');

    let response: Response;
    try {
      response = await fetch(
        `${VERIFY_BASE_URL}/Services/${serviceSid}/${resource}`,
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${auth}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body,
        },
      );
    } catch (error) {
      this.logger.error(
        `Network error calling Twilio Verify (${resource}) for ${phone}`,
        error instanceof Error ? error.stack : String(error),
      );
      throw new BadRequestException('Could not reach the verification service');
    }

    const json = (await response.json().catch(() => ({}))) as {
      code?: number;
      status?: string;
    };
    return { response, json };
  }
}
