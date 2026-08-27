import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { OtpController } from './otp.controller';
import { TokensService } from './tokens.service';
import { OtpThrottleService } from './otp-throttle.service';
import { TwilioVerifyService } from './twilio-verify.service';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { BlacklistedPhone } from '../database/entities/blacklisted-phone.entity';
import { UserRole } from '../database/enums/user-role.enum';

describe('OtpController', () => {
  let controller: OtpController;
  let twilioVerify: {
    resolveChannel: jest.Mock;
    startVerification: jest.Mock;
    checkVerification: jest.Mock;
  };
  let throttle: {
    assertCanSend: jest.Mock;
    recordSend: jest.Mock;
    assertCanCheck: jest.Mock;
    recordFailedCode: jest.Mock;
    recordSuccess: jest.Mock;
  };
  let tokensService: {
    issueTokens: jest.Mock;
    issueRegistrationToken: jest.Mock;
  };
  let userRepository: { findOne: jest.Mock };
  let craftsmanProfileRepository: { findOne: jest.Mock };
  let blacklistedPhoneRepository: { findOne: jest.Mock };

  const PHONE = '+2250700000001';

  beforeEach(async () => {
    twilioVerify = {
      resolveChannel: jest.fn().mockReturnValue('whatsapp'),
      startVerification: jest.fn().mockResolvedValue(undefined),
      checkVerification: jest.fn().mockResolvedValue('approved'),
    };
    throttle = {
      assertCanSend: jest.fn().mockResolvedValue(undefined),
      recordSend: jest.fn().mockResolvedValue(undefined),
      assertCanCheck: jest.fn().mockResolvedValue(undefined),
      recordFailedCode: jest.fn().mockResolvedValue(undefined),
      recordSuccess: jest.fn().mockResolvedValue(undefined),
    };
    tokensService = {
      issueTokens: jest
        .fn()
        .mockResolvedValue({ accessToken: 'a', refreshToken: 'r' }),
      issueRegistrationToken: jest.fn().mockResolvedValue('reg-token'),
    };
    userRepository = { findOne: jest.fn().mockResolvedValue(null) };
    craftsmanProfileRepository = { findOne: jest.fn().mockResolvedValue(null) };
    blacklistedPhoneRepository = { findOne: jest.fn().mockResolvedValue(null) };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [OtpController],
      providers: [
        { provide: TwilioVerifyService, useValue: twilioVerify },
        { provide: OtpThrottleService, useValue: throttle },
        { provide: TokensService, useValue: tokensService },
        { provide: getRepositoryToken(User), useValue: userRepository },
        {
          provide: getRepositoryToken(CraftsmanProfile),
          useValue: craftsmanProfileRepository,
        },
        {
          provide: getRepositoryToken(BlacklistedPhone),
          useValue: blacklistedPhoneRepository,
        },
      ],
    }).compile();

    controller = module.get(OtpController);
  });

  describe('start', () => {
    it('sends via the resolved channel and records the send', async () => {
      const result = await controller.start({ phone: PHONE });

      expect(throttle.assertCanSend).toHaveBeenCalledWith(PHONE);
      expect(twilioVerify.startVerification).toHaveBeenCalledWith(
        PHONE,
        'whatsapp',
      );
      expect(throttle.recordSend).toHaveBeenCalledWith(PHONE);
      expect(result).toEqual({ status: 'sent', channel: 'whatsapp' });
    });

    it('rejects a blacklisted phone before sending anything', async () => {
      blacklistedPhoneRepository.findOne.mockResolvedValue({ id: 'bl-1' });

      await expect(controller.start({ phone: PHONE })).rejects.toThrow(
        ForbiddenException,
      );
      expect(twilioVerify.startVerification).not.toHaveBeenCalled();
    });
  });

  describe('check', () => {
    it('returns a registrationToken for a brand-new phone', async () => {
      const result = await controller.check({ phone: PHONE, code: '123456' });

      expect(throttle.recordSuccess).toHaveBeenCalledWith(PHONE);
      expect(result).toEqual({ status: 'new', registrationToken: 'reg-token' });
    });

    it('returns a full session (with tier) for an existing craftsman account', async () => {
      userRepository.findOne.mockResolvedValue({
        id: 'u-1',
        phone: PHONE,
        fullName: 'Kofi Yao',
        role: UserRole.CRAFTSMAN,
        deletedAt: null,
      });
      craftsmanProfileRepository.findOne.mockResolvedValue({
        subscriptionTier: 'silver',
      });

      const result = await controller.check({ phone: PHONE, code: '123456' });

      expect(result).toMatchObject({
        status: 'existing',
        accessToken: 'a',
        refreshToken: 'r',
        user: {
          id: 'u-1',
          role: UserRole.CRAFTSMAN,
          subscriptionTier: 'silver',
        },
      });
    });

    it('records a failed code and throws Unauthorized on a wrong code', async () => {
      twilioVerify.checkVerification.mockResolvedValue('invalid');

      await expect(
        controller.check({ phone: PHONE, code: '000000' }),
      ).rejects.toThrow(UnauthorizedException);
      expect(throttle.recordFailedCode).toHaveBeenCalledWith(PHONE);
      expect(tokensService.issueRegistrationToken).not.toHaveBeenCalled();
    });

    it('treats a soft-deleted account as new (no session handed back)', async () => {
      userRepository.findOne.mockResolvedValue({
        id: 'u-1',
        phone: PHONE,
        role: UserRole.CLIENT,
        deletedAt: new Date(),
      });

      const result = await controller.check({ phone: PHONE, code: '123456' });

      expect(result).toEqual({ status: 'new', registrationToken: 'reg-token' });
    });
  });
});
