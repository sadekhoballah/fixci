import { Test, TestingModule } from '@nestjs/testing';
import { OtpService } from './otp.service';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { WhatsappService } from '../whatsapp/whatsapp.service';

describe('OtpService', () => {
  let service: OtpService;
  let redis: { get: jest.Mock; set: jest.Mock; del: jest.Mock };
  let whatsapp: { isConfigured: boolean; sendOtpMessage: jest.Mock };
  const originalEnv = process.env.NODE_ENV;

  beforeEach(async () => {
    redis = { get: jest.fn(), set: jest.fn(), del: jest.fn() };
    whatsapp = { isConfigured: true, sendOtpMessage: jest.fn().mockResolvedValue(undefined) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OtpService,
        { provide: REDIS_CLIENT, useValue: redis },
        { provide: WhatsappService, useValue: whatsapp },
      ],
    }).compile();

    service = module.get(OtpService);
  });

  afterEach(() => {
    process.env.NODE_ENV = originalEnv;
  });

  describe('requestOtp', () => {
    it('stores a 6-digit code with a TTL and sends it via WhatsApp when configured', async () => {
      await service.requestOtp('+2250700000001');

      expect(redis.set).toHaveBeenCalledWith(
        'otp:+2250700000001',
        expect.any(String),
        'EX',
        300,
      );
      const stored: { code: string; attempts: number } = JSON.parse(
        redis.set.mock.calls[0][1] as string,
      );
      expect(stored.code).toMatch(/^\d{6}$/);
      expect(stored.attempts).toBe(0);
      expect(whatsapp.sendOtpMessage).toHaveBeenCalledWith(
        '+2250700000001',
        stored.code,
      );
    });

    it('logs instead of calling WhatsApp when unconfigured outside production', async () => {
      process.env.NODE_ENV = 'development';
      whatsapp.isConfigured = false;

      await service.requestOtp('+2250700000002');

      expect(whatsapp.sendOtpMessage).not.toHaveBeenCalled();
    });

    it('still calls WhatsApp (and lets it throw) when unconfigured in production', async () => {
      process.env.NODE_ENV = 'production';
      whatsapp.isConfigured = false;

      await service.requestOtp('+2250700000003');

      expect(whatsapp.sendOtpMessage).toHaveBeenCalled();
    });
  });

  describe('verifyOtp', () => {
    it('returns expired when there is no stored record', async () => {
      redis.get.mockResolvedValue(null);
      await expect(service.verifyOtp('+2250700000004', '123456')).resolves.toBe(
        'expired',
      );
    });

    it('returns valid and deletes the record on a correct code', async () => {
      redis.get.mockResolvedValue(JSON.stringify({ code: '482913', attempts: 0 }));
      await expect(service.verifyOtp('+2250700000005', '482913')).resolves.toBe(
        'valid',
      );
      expect(redis.del).toHaveBeenCalledWith('otp:+2250700000005');
    });

    it('returns invalid and keeps the record (with an incremented attempt count) on a wrong code', async () => {
      redis.get.mockResolvedValue(JSON.stringify({ code: '482913', attempts: 0 }));
      await expect(service.verifyOtp('+2250700000006', '000000')).resolves.toBe(
        'invalid',
      );
      expect(redis.del).not.toHaveBeenCalled();
      const [, savedRaw, mode] = redis.set.mock.calls[0] as [string, string, string];
      expect(JSON.parse(savedRaw)).toEqual({ code: '482913', attempts: 1 });
      expect(mode).toBe('KEEPTTL');
    });

    it('returns too_many_attempts and deletes the record once the budget is exhausted', async () => {
      redis.get.mockResolvedValue(JSON.stringify({ code: '482913', attempts: 4 }));
      await expect(service.verifyOtp('+2250700000007', '000000')).resolves.toBe(
        'too_many_attempts',
      );
      expect(redis.del).toHaveBeenCalledWith('otp:+2250700000007');
    });
  });
});
