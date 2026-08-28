import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { UnauthorizedException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { UsersService } from './users.service';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { District } from '../database/entities/district.entity';
import { BlacklistedPhone } from '../database/entities/blacklisted-phone.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { TokensService } from '../auth/tokens.service';
import { PresenceService } from '../matching/presence.service';
import { REDIS_CLIENT } from '../redis/redis.constants';

describe('UsersService', () => {
  let service: UsersService;
  let userRepository: { findOne: jest.Mock };
  let districtRepository: { findOne: jest.Mock };
  let blacklistedPhoneRepository: { findOne: jest.Mock };
  let dataSource: { transaction: jest.Mock };
  let tokensService: { verifyRegistrationToken: jest.Mock };
  let manager: { create: jest.Mock; save: jest.Mock };

  beforeEach(async () => {
    manager = {
      create: jest.fn((_entity: unknown, data: unknown) => data),
      save: jest.fn((data: Record<string, unknown>) =>
        Promise.resolve({ id: 'generated-user-id', ...data }),
      ),
    };
    userRepository = { findOne: jest.fn().mockResolvedValue(null) };
    districtRepository = {
      findOne: jest.fn().mockResolvedValue({ id: 'district-1' }),
    };
    blacklistedPhoneRepository = { findOne: jest.fn().mockResolvedValue(null) };
    dataSource = {
      transaction: jest.fn((cb: (m: typeof manager) => unknown) => cb(manager)),
    };
    tokensService = {
      verifyRegistrationToken: jest.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: getRepositoryToken(User), useValue: userRepository },
        { provide: getRepositoryToken(CraftsmanProfile), useValue: {} },
        { provide: getRepositoryToken(ClientProfile), useValue: {} },
        { provide: getRepositoryToken(District), useValue: districtRepository },
        {
          provide: getRepositoryToken(BlacklistedPhone),
          useValue: blacklistedPhoneRepository,
        },
        { provide: DataSource, useValue: dataSource },
        { provide: TokensService, useValue: tokensService },
        { provide: PresenceService, useValue: {} },
        {
          provide: REDIS_CLIENT,
          useValue: { get: jest.fn().mockResolvedValue(null), del: jest.fn() },
        },
      ],
    }).compile();

    service = module.get(UsersService);
  });

  it('verifies the registration token against the phone and creates the user as phoneVerified=true', async () => {
    const user = await service.register({
      phone: '+2250700000010',
      role: UserRole.CLIENT,
      fullName: 'Aya Kone',
      idCardStorageKey: 'id-cards/aya.png',
      districtId: 'district-1',
      registrationToken: 'valid-registration-token',
    });

    expect(tokensService.verifyRegistrationToken).toHaveBeenCalledWith(
      'valid-registration-token',
      '+2250700000010',
    );
    expect(user.phoneVerified).toBe(true);
  });

  it('propagates a mismatch/invalid token as UnauthorizedException and creates no user', async () => {
    tokensService.verifyRegistrationToken.mockRejectedValue(
      new UnauthorizedException(
        'Registration token does not match the phone number being registered',
      ),
    );

    await expect(
      service.register({
        phone: '+2250700000012',
        role: UserRole.CLIENT,
        fullName: 'Aya Kone',
        idCardStorageKey: 'id-cards/aya.png',
        districtId: 'district-1',
        registrationToken: 'token-for-a-different-phone',
      }),
    ).rejects.toThrow(UnauthorizedException);

    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it('rejects a blacklisted phone without creating a user, before checking the token', async () => {
    blacklistedPhoneRepository.findOne.mockResolvedValue({ id: 'bl-1' });

    await expect(
      service.register({
        phone: '+2250700000013',
        role: UserRole.CLIENT,
        fullName: 'Aya Kone',
        idCardStorageKey: 'id-cards/aya.png',
        districtId: 'district-1',
        registrationToken: 'valid-registration-token',
      }),
    ).rejects.toThrow('This phone number cannot be registered');

    expect(tokensService.verifyRegistrationToken).not.toHaveBeenCalled();
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it('creates a craftsman profile with the service category and id card key', async () => {
    await service.register({
      phone: '+2250700000014',
      role: UserRole.CRAFTSMAN,
      fullName: 'Kofi Yao',
      serviceCategory: 'plumber' as never,
      idCardStorageKey: 'id-cards/abc.png',
      districtId: 'district-1',
      registrationToken: 'valid-registration-token',
    });

    expect(manager.create).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        serviceCategory: 'plumber',
        idCardStorageKey: 'id-cards/abc.png',
      }),
    );
  });
});
