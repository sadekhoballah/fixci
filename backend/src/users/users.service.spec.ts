import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { UsersService } from './users.service';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { District } from '../database/entities/district.entity';
import { BlacklistedPhone } from '../database/entities/blacklisted-phone.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { PresenceService } from '../matching/presence.service';

describe('UsersService', () => {
  let service: UsersService;
  let userRepository: { findOne: jest.Mock };
  let districtRepository: { findOne: jest.Mock };
  let blacklistedPhoneRepository: { findOne: jest.Mock };
  let dataSource: { transaction: jest.Mock };
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
        { provide: PresenceService, useValue: {} },
      ],
    }).compile();

    service = module.get(UsersService);
  });

  // No phone verification happens before registration for this phase (see
  // ReconnectController's doc comment) — phoneVerified is left at its column
  // default rather than ever being set true here.
  it('creates the user without requiring or setting phone verification', async () => {
    const user = await service.register({
      phone: '+2250700000010',
      role: UserRole.CLIENT,
      fullName: 'Aya Kone',
      idCardStorageKey: 'id-cards/aya.png',
      districtId: 'district-1',
    });

    const [, createArgs] = manager.create.mock.calls[0] as [
      unknown,
      Record<string, unknown>,
    ];
    expect(createArgs).not.toHaveProperty('phoneVerified');
    expect(user.phoneVerified).toBeUndefined();
  });

  it('rejects a blacklisted phone without creating a user', async () => {
    blacklistedPhoneRepository.findOne.mockResolvedValue({ id: 'bl-1' });

    await expect(
      service.register({
        phone: '+2250700000013',
        role: UserRole.CLIENT,
        fullName: 'Aya Kone',
        idCardStorageKey: 'id-cards/aya.png',
        districtId: 'district-1',
      }),
    ).rejects.toThrow('This phone number cannot be registered');

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
