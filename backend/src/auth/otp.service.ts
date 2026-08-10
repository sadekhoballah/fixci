import { Inject, Injectable, Logger } from '@nestjs/common';
import { randomInt } from 'crypto';
import Redis from 'ioredis';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { WhatsappService } from '../whatsapp/whatsapp.service';

const DEFAULT_OTP_TTL_SECONDS = 300;
const MAX_VERIFY_ATTEMPTS = 5;

interface OtpRecord {
  code: string;
  attempts: number;
}

export type VerifyOtpResult = 'valid' | 'invalid' | 'expired' | 'too_many_attempts';

// OTPs are ephemeral, TTL-bound data — Redis (already wired for presence,
// see matching/presence.service.ts) is a better fit than a Postgres table
// that would need its own expiry sweep.
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
    private readonly whatsapp: WhatsappService,
  ) {}

  private key(phone: string): string {
    return `otp:${phone}`;
  }

  private get ttlSeconds(): number {
    return Number(process.env.OTP_TTL_SECONDS ?? DEFAULT_OTP_TTL_SECONDS);
  }

  // Generates a fresh code, stores it, and sends it. A new request always
  // overwrites any code still pending for that phone (and resets the
  // attempt counter) — there's no point keeping an old code alive once a
  // new one has been sent, and this also caps a caller's exposure to
  // MAX_VERIFY_ATTEMPTS per *code* rather than per time window.
  async requestOtp(phone: string): Promise<void> {
    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const record: OtpRecord = { code, attempts: 0 };
    await this.redis.set(
      this.key(phone),
      JSON.stringify(record),
      'EX',
      this.ttlSeconds,
    );

    // Outside production, tolerate WhatsApp not being configured yet the
    // same way FirebaseAdminModule used to tolerate a missing service
    // account — log the code instead of failing local dev outright.
    if (!this.whatsapp.isConfigured && process.env.NODE_ENV !== 'production') {
      this.logger.warn(`OTP for ${phone} is ${code} (WhatsApp not configured)`);
      return;
    }

    await this.whatsapp.sendOtpMessage(phone, code);
  }

  // Deletes the record on a valid code (one-time use) or once the attempt
  // budget is exhausted (forces a fresh requestOtp rather than letting a
  // caller keep guessing against the same code indefinitely). A wrong guess
  // that still has attempts left just increments the counter in place.
  async verifyOtp(phone: string, code: string): Promise<VerifyOtpResult> {
    const raw = await this.redis.get(this.key(phone));
    if (!raw) return 'expired';

    const record = JSON.parse(raw) as OtpRecord;
    if (record.code === code) {
      await this.redis.del(this.key(phone));
      return 'valid';
    }

    record.attempts += 1;
    if (record.attempts >= MAX_VERIFY_ATTEMPTS) {
      await this.redis.del(this.key(phone));
      return 'too_many_attempts';
    }

    await this.redis.set(
      this.key(phone),
      JSON.stringify(record),
      'KEEPTTL',
    );
    return 'invalid';
  }
}
