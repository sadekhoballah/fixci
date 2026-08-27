import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import {
  OtpThrottleService,
  OTP_THROTTLE_MESSAGE,
} from './otp-throttle.service';
import { REDIS_CLIENT } from '../redis/redis.constants';

// Minimal in-memory Redis good enough for the ladder logic: string values,
// key presence, INCR, and DEL. TTLs are accepted and ignored (no test here
// depends on wall-clock expiry — each test starts from a fresh store).
function fakeRedis() {
  const store = new Map<string, string>();
  return {
    store,
    exists: jest.fn((key: string) => Promise.resolve(store.has(key) ? 1 : 0)),
    get: jest.fn((key: string) => Promise.resolve(store.get(key) ?? null)),
    set: jest.fn((key: string, value: string) => {
      store.set(key, value);
      return Promise.resolve('OK');
    }),
    incr: jest.fn((key: string) => {
      const next = Number(store.get(key) ?? 0) + 1;
      store.set(key, String(next));
      return Promise.resolve(next);
    }),
    expire: jest.fn(() => Promise.resolve(1)),
    del: jest.fn((...keys: string[]) => {
      let removed = 0;
      for (const key of keys) if (store.delete(key)) removed += 1;
      return Promise.resolve(removed);
    }),
  };
}

describe('OtpThrottleService', () => {
  let service: OtpThrottleService;
  let redis: ReturnType<typeof fakeRedis>;
  const PHONE = '+2250700000001';

  beforeEach(async () => {
    redis = fakeRedis();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OtpThrottleService,
        { provide: REDIS_CLIENT, useValue: redis },
      ],
    }).compile();
    service = module.get(OtpThrottleService);
  });

  it('allows the first send, then blocks a resend during the 60s cooldown', async () => {
    await service.assertCanSend(PHONE);
    await service.recordSend(PHONE);

    expect(redis.set).toHaveBeenCalledWith('otp:cd:' + PHONE, '1', 'EX', 60);
    await expect(service.assertCanSend(PHONE)).rejects.toThrow(
      OTP_THROTTLE_MESSAGE.cooldown,
    );
  });

  it('blocks the 4th send within the hour (max 3 per hour)', async () => {
    for (let i = 0; i < 3; i += 1) {
      redis.store.delete('otp:cd:' + PHONE); // skip the cooldown between sends
      await service.assertCanSend(PHONE);
      await service.recordSend(PHONE);
    }
    redis.store.delete('otp:cd:' + PHONE);

    await expect(service.assertCanSend(PHONE)).rejects.toThrow(
      OTP_THROTTLE_MESSAGE.hourlyLimit,
    );
  });

  it('applies a 5-minute block after 2 fully-failed code entries', async () => {
    await service.recordFailedCode(PHONE);
    await expect(service.assertCanCheck(PHONE)).resolves.toBeUndefined();

    await service.recordFailedCode(PHONE);

    expect(redis.store.has('otp:block5:' + PHONE)).toBe(true);
    await expect(service.assertCanCheck(PHONE)).rejects.toThrow(
      OTP_THROTTLE_MESSAGE.blockedMinutes,
    );
    await expect(service.assertCanSend(PHONE)).rejects.toThrow(
      OTP_THROTTLE_MESSAGE.blockedMinutes,
    );
  });

  it('escalates to a 24-hour lock the second time the 5-minute block is hit', async () => {
    // First 5-min block.
    await service.recordFailedCode(PHONE);
    await service.recordFailedCode(PHONE);
    redis.store.delete('otp:block5:' + PHONE); // 5 min elapse

    // Second 5-min block -> 24h lock.
    await service.recordFailedCode(PHONE);
    await service.recordFailedCode(PHONE);

    expect(redis.store.has('otp:lock24:' + PHONE)).toBe(true);
    await expect(service.assertCanCheck(PHONE)).rejects.toThrow(
      OTP_THROTTLE_MESSAGE.locked24h,
    );
  });

  it('recordSuccess clears every counter and block for the phone', async () => {
    await service.recordSend(PHONE);
    await service.recordFailedCode(PHONE);
    await service.recordFailedCode(PHONE);

    await service.recordSuccess(PHONE);

    expect(redis.store.size).toBe(0);
    await expect(service.assertCanSend(PHONE)).resolves.toBeUndefined();
    await expect(service.assertCanCheck(PHONE)).resolves.toBeUndefined();
  });

  it('throws ForbiddenException (not a generic error) when blocked', async () => {
    await service.recordFailedCode(PHONE);
    await service.recordFailedCode(PHONE);

    await expect(service.assertCanCheck(PHONE)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });
});
