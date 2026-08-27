import { ForbiddenException, Inject, Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { REDIS_CLIENT } from '../redis/redis.constants';

// Machine-readable messages the mobile client maps to localized copy — same
// pattern as the old OtpController's VERIFY_ERROR_MESSAGE table. Keep these
// strings stable; verify_service.dart switches on them verbatim.
export const OTP_THROTTLE_MESSAGE = {
  locked24h: 'Too many attempts — try again in 24 hours',
  blockedMinutes: 'Too many attempts — try again in a few minutes',
  cooldown: 'Please wait before requesting another code',
  hourlyLimit: 'Too many codes requested — try again later',
} as const;

const COOLDOWN_SECONDS = 60;
const HOUR_SECONDS = 3600;
const DAY_SECONDS = 86_400;
const BLOCK_5_SECONDS = 300;

const MAX_SENDS_PER_HOUR = 3;
const FAILS_BEFORE_BLOCK = 2;
const BLOCKS_BEFORE_LOCK = 2;

// The application-level abuse ladder layered on top of Twilio Verify's own
// per-code fraud limits: resend cooldown 60s, max 3 sends/phone/hour, a
// 5-minute block after 2 fully-failed code entries, and a 24-hour lock the
// second time that 5-minute block is hit inside a day. Redis-backed (already
// wired for presence — see matching/presence.service.ts), TTL-bound so
// there's no sweep to run.
@Injectable()
export class OtpThrottleService {
  constructor(@Inject(REDIS_CLIENT) private readonly redis: Redis) {}

  private keys(phone: string) {
    return {
      cooldown: `otp:cd:${phone}`,
      sends: `otp:sends:${phone}`,
      fails: `otp:fails:${phone}`,
      block5: `otp:block5:${phone}`,
      blockCount: `otp:blockcount:${phone}`,
      lock24: `otp:lock24:${phone}`,
    };
  }

  async assertCanSend(phone: string): Promise<void> {
    const k = this.keys(phone);
    if (await this.redis.exists(k.lock24)) {
      throw new ForbiddenException(OTP_THROTTLE_MESSAGE.locked24h);
    }
    if (await this.redis.exists(k.block5)) {
      throw new ForbiddenException(OTP_THROTTLE_MESSAGE.blockedMinutes);
    }
    if (await this.redis.exists(k.cooldown)) {
      throw new ForbiddenException(OTP_THROTTLE_MESSAGE.cooldown);
    }
    const sends = Number((await this.redis.get(k.sends)) ?? 0);
    if (sends >= MAX_SENDS_PER_HOUR) {
      throw new ForbiddenException(OTP_THROTTLE_MESSAGE.hourlyLimit);
    }
  }

  async recordSend(phone: string): Promise<void> {
    const k = this.keys(phone);
    await this.redis.set(k.cooldown, '1', 'EX', COOLDOWN_SECONDS);
    const sends = await this.redis.incr(k.sends);
    if (sends === 1) await this.redis.expire(k.sends, HOUR_SECONDS);
  }

  async assertCanCheck(phone: string): Promise<void> {
    const k = this.keys(phone);
    if (await this.redis.exists(k.lock24)) {
      throw new ForbiddenException(OTP_THROTTLE_MESSAGE.locked24h);
    }
    if (await this.redis.exists(k.block5)) {
      throw new ForbiddenException(OTP_THROTTLE_MESSAGE.blockedMinutes);
    }
  }

  // A "fully-failed code entry" = one POST /auth/otp/check that Twilio did
  // not approve (wrong, expired, or Twilio's own attempt ceiling hit).
  async recordFailedCode(phone: string): Promise<void> {
    const k = this.keys(phone);
    const fails = await this.redis.incr(k.fails);
    if (fails === 1) await this.redis.expire(k.fails, HOUR_SECONDS);
    if (fails < FAILS_BEFORE_BLOCK) return;

    await this.redis.set(k.block5, '1', 'EX', BLOCK_5_SECONDS);
    await this.redis.del(k.fails);
    const blocks = await this.redis.incr(k.blockCount);
    if (blocks === 1) await this.redis.expire(k.blockCount, DAY_SECONDS);
    if (blocks >= BLOCKS_BEFORE_LOCK) {
      await this.redis.set(k.lock24, '1', 'EX', DAY_SECONDS);
    }
  }

  async recordSuccess(phone: string): Promise<void> {
    const k = this.keys(phone);
    await this.redis.del(
      k.cooldown,
      k.sends,
      k.fails,
      k.block5,
      k.blockCount,
      k.lock24,
    );
  }
}
