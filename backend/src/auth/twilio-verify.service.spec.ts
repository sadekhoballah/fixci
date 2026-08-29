import { BadRequestException } from '@nestjs/common';
import { TwilioVerifyService } from './twilio-verify.service';

describe('TwilioVerifyService', () => {
  let service: TwilioVerifyService;
  const fetchMock = jest.fn();
  const originalEnv = { ...process.env };

  const jsonResponse = (status: number, body: unknown) =>
    ({
      ok: status >= 200 && status < 300,
      status,
      json: () => Promise.resolve(body),
    }) as unknown as Response;

  beforeEach(() => {
    service = new TwilioVerifyService();
    fetchMock.mockReset();
    global.fetch = fetchMock;
    process.env.TWILIO_ACCOUNT_SID = 'AC_test';
    process.env.TWILIO_AUTH_TOKEN = 'tok_test';
    process.env.TWILIO_VERIFY_SERVICE_SID = 'VA_test';
    delete process.env.TWILIO_VERIFY_WHATSAPP_ENABLED;
    delete process.env.TWILIO_VERIFY_SMS_ENABLED;
    delete process.env.TWILIO_VERIFY_LOCALE;
    delete process.env.TWILIO_VERIFY_WA_TEMPLATE_SID;
    process.env.NODE_ENV = 'test';
  });

  afterEach(() => {
    process.env = { ...originalEnv };
  });

  describe('resolveChannel', () => {
    it('defaults to whatsapp and honours an explicit sms request', () => {
      expect(service.resolveChannel(undefined)).toBe('whatsapp');
      expect(service.resolveChannel('sms')).toBe('sms');
    });

    it('forces sms when TWILIO_VERIFY_WHATSAPP_ENABLED is "false"', () => {
      process.env.TWILIO_VERIFY_WHATSAPP_ENABLED = 'false';
      expect(service.resolveChannel('whatsapp')).toBe('sms');
    });

    it('forces whatsapp when TWILIO_VERIFY_SMS_ENABLED is "false"', () => {
      process.env.TWILIO_VERIFY_SMS_ENABLED = 'false';
      expect(service.resolveChannel('sms')).toBe('whatsapp');
      expect(service.resolveChannel(undefined)).toBe('whatsapp');
    });

    it('lets WhatsApp-disabled win when both kill-switches are set', () => {
      process.env.TWILIO_VERIFY_WHATSAPP_ENABLED = 'false';
      process.env.TWILIO_VERIFY_SMS_ENABLED = 'false';
      expect(service.resolveChannel('whatsapp')).toBe('sms');
    });
  });

  describe('startVerification', () => {
    it('POSTs To/Channel to the Verifications resource with basic auth', async () => {
      fetchMock.mockResolvedValue(jsonResponse(201, { status: 'pending' }));

      await service.startVerification('+2250700000001', 'whatsapp');

      const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect(url).toBe(
        'https://verify.twilio.com/v2/Services/VA_test/Verifications',
      );
      expect((init.headers as Record<string, string>).Authorization).toBe(
        `Basic ${Buffer.from('AC_test:tok_test').toString('base64')}`,
      );
      expect((init.body as URLSearchParams).get('To')).toBe('+2250700000001');
      expect((init.body as URLSearchParams).get('Channel')).toBe('whatsapp');
      expect((init.body as URLSearchParams).has('Locale')).toBe(false);
      expect((init.body as URLSearchParams).has('TemplateSid')).toBe(false);
    });

    it('adds Locale from TWILIO_VERIFY_LOCALE', async () => {
      process.env.TWILIO_VERIFY_LOCALE = 'fr';
      fetchMock.mockResolvedValue(jsonResponse(201, { status: 'pending' }));

      await service.startVerification('+2250700000001', 'sms');

      const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect((init.body as URLSearchParams).get('Locale')).toBe('fr');
    });

    it('forces an HJ… TemplateSid on the WhatsApp channel only', async () => {
      process.env.TWILIO_VERIFY_WA_TEMPLATE_SID = 'HJ' + '0'.repeat(32);
      fetchMock.mockResolvedValue(jsonResponse(201, { status: 'pending' }));

      await service.startVerification('+2250700000001', 'whatsapp');
      const [, waInit] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect((waInit.body as URLSearchParams).get('TemplateSid')).toBe(
        'HJ' + '0'.repeat(32),
      );

      fetchMock.mockClear();
      await service.startVerification('+2250700000001', 'sms');
      const [, smsInit] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect((smsInit.body as URLSearchParams).has('TemplateSid')).toBe(false);
    });

    it('ignores a mistaken HX… Content SID in TWILIO_VERIFY_WA_TEMPLATE_SID', async () => {
      process.env.TWILIO_VERIFY_WA_TEMPLATE_SID = 'HX' + 'a'.repeat(32);
      fetchMock.mockResolvedValue(jsonResponse(201, { status: 'pending' }));

      await service.startVerification('+2250700000001', 'whatsapp');

      const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect((init.body as URLSearchParams).has('TemplateSid')).toBe(false);
    });

    it('maps Twilio invalid-number (60200) to BadRequestException', async () => {
      fetchMock.mockResolvedValue(jsonResponse(400, { code: 60200 }));

      await expect(service.startVerification('+100', 'sms')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('is a no-op outside production when Twilio is not configured', async () => {
      delete process.env.TWILIO_AUTH_TOKEN;
      process.env.NODE_ENV = 'development';

      await service.startVerification('+2250700000001', 'sms');

      expect(fetchMock).not.toHaveBeenCalled();
    });
  });

  describe('checkVerification', () => {
    it('returns "approved" when Twilio approves the code', async () => {
      fetchMock.mockResolvedValue(jsonResponse(200, { status: 'approved' }));

      await expect(
        service.checkVerification('+2250700000001', '123456'),
      ).resolves.toBe('approved');
    });

    it('returns "invalid" when Twilio leaves the check pending', async () => {
      fetchMock.mockResolvedValue(jsonResponse(200, { status: 'pending' }));

      await expect(
        service.checkVerification('+2250700000001', '000000'),
      ).resolves.toBe('invalid');
    });

    it('returns "expired" on a 404 (verification consumed or never sent)', async () => {
      fetchMock.mockResolvedValue(jsonResponse(404, { code: 20404 }));

      await expect(
        service.checkVerification('+2250700000001', '123456'),
      ).resolves.toBe('expired');
    });

    it('returns "too_many_attempts" when Twilio reports its own attempt ceiling', async () => {
      fetchMock.mockResolvedValue(jsonResponse(429, { code: 60202 }));

      await expect(
        service.checkVerification('+2250700000001', '123456'),
      ).resolves.toBe('too_many_attempts');
    });

    it('dev bypass: only the fixed 000000 code approves when unconfigured', async () => {
      delete process.env.TWILIO_AUTH_TOKEN;
      process.env.NODE_ENV = 'development';

      await expect(
        service.checkVerification('+2250700000001', '000000'),
      ).resolves.toBe('approved');
      await expect(
        service.checkVerification('+2250700000001', '123456'),
      ).resolves.toBe('invalid');
      expect(fetchMock).not.toHaveBeenCalled();
    });
  });
});
