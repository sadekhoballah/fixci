import { Test, TestingModule } from '@nestjs/testing';
import { WhatsappSendError, WhatsappService } from './whatsapp.service';

describe('WhatsappService', () => {
  let service: WhatsappService;
  let fetchMock: jest.Mock;
  const originalEnv = { ...process.env };

  beforeEach(async () => {
    fetchMock = jest.fn().mockResolvedValue({ ok: true } as Response);
    global.fetch = fetchMock as unknown as typeof fetch;

    process.env.WHATSAPP_ACCESS_TOKEN = 'test-token';
    process.env.WHATSAPP_PHONE_NUMBER_ID = '123456';
    process.env.WHATSAPP_OTP_TEMPLATE_NAME = 'otp_auth';
    delete process.env.WHATSAPP_OTP_TEMPLATE_LANG;
    delete process.env.WHATSAPP_OTP_TEMPLATE_HAS_BUTTON;

    const module: TestingModule = await Test.createTestingModule({
      providers: [WhatsappService],
    }).compile();

    service = module.get(WhatsappService);
  });

  afterEach(() => {
    process.env = { ...originalEnv };
    jest.restoreAllMocks();
  });

  function sentComponents() {
    const body = JSON.parse(fetchMock.mock.calls[0][1].body);
    return body.template.components;
  }

  it('includes a button component matching the code by default (Authentication category default)', async () => {
    await service.sendOtpMessage('+2250700000001', '123456');

    expect(sentComponents()).toEqual([
      { type: 'body', parameters: [{ type: 'text', text: '123456' }] },
      {
        type: 'button',
        sub_type: 'url',
        index: '0',
        parameters: [{ type: 'text', text: '123456' }],
      },
    ]);
  });

  it('omits the button component when WHATSAPP_OTP_TEMPLATE_HAS_BUTTON=false', async () => {
    process.env.WHATSAPP_OTP_TEMPLATE_HAS_BUTTON = 'false';

    await service.sendOtpMessage('+2250700000001', '123456');

    expect(sentComponents()).toEqual([
      { type: 'body', parameters: [{ type: 'text', text: '123456' }] },
    ]);
  });

  it('strips the leading "+" from the recipient number', async () => {
    await service.sendOtpMessage('+2250700000001', '123456');

    const body = JSON.parse(fetchMock.mock.calls[0][1].body);
    expect(body.to).toBe('2250700000001');
  });

  it('throws when WhatsApp Cloud API rejects the message', async () => {
    fetchMock.mockResolvedValue({ ok: false, status: 400, text: async () => 'bad template' });

    await expect(service.sendOtpMessage('+2250700000001', '123456')).rejects.toThrow(
      WhatsappSendError,
    );
  });

  it('throws when required config is missing', async () => {
    delete process.env.WHATSAPP_OTP_TEMPLATE_NAME;

    await expect(service.sendOtpMessage('+2250700000001', '123456')).rejects.toThrow(
      WhatsappSendError,
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
