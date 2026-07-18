import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { UnauthorizedException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { UsersService } from './users.service';
import { User } from '../database/entities/user.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { PhoneTokenVerifierService } from '../firebase/phone-token-verifier.service';

describe('UsersService', () => {
  let service: UsersService;
  let userRepository: { findOne: jest.Mock };
  let dataSource: { transaction: jest.Mock };
  let phoneTokenVerifier: { verifyPhoneToken: jest.Mock };
  let manager: { create: jest.Mock; save: jest.Mock };

  beforeEach(async () => {
    manager = {
      create: jest.fn((_entity: unknown, data: unknown) => data),
      save: jest.fn((data: Record<string, unknown>) =>
        Promise.resolve({ id: 'generated-user-id', ...data }),
      ),
    };
    userRepository = { findOne: jest.fn().mockResolvedValue(null) };
    dataSource = {
      transaction: jest.fn((cb: (m: typeof manager) => unknown) => cb(manager)),
    };
    phoneTokenVerifier = { verifyPhoneToken: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: getRepositoryToken(User), useValue: userRepository },
        { provide: DataSource, useValue: dataSource },
        { provide: PhoneTokenVerifierService, useValue: phoneTokenVerifier },
      ],
    }).compile();

    service = module.get(UsersService);
  });

  it('registers without a token as phoneVerified=false, never calling the verifier', async () => {
    const user = await service.register({
      phone: '+2250700000010',
      role: UserRole.CLIENT,
    });

    expect(phoneTokenVerifier.verifyPhoneToken).not.toHaveBeenCalled();
    expect(user.phoneVerified).toBe(false);
  });

  it('sets phoneVerified=true when the token verifies and matches the phone', async () => {
    phoneTokenVerifier.verifyPhoneToken.mockResolvedValue({ verified: true });

    const user = await service.register({
      phone: '+2250700000011',
      role: UserRole.CLIENT,
      firebaseIdToken: 'valid-token',
    });

    expect(phoneTokenVerifier.verifyPhoneToken).toHaveBeenCalledWith(
      'valid-token',
      '+2250700000011',
    );
    expect(user.phoneVerified).toBe(true);
  });

  it('propagates a mismatch as UnauthorizedException and creates no user', async () => {
    phoneTokenVerifier.verifyPhoneToken.mockRejectedValue(
      new UnauthorizedException(
        'Verification token does not match the phone number being registered',
      ),
    );

    await expect(
      service.register({
        phone: '+2250700000012',
        role: UserRole.CLIENT,
        firebaseIdToken: 'token-for-a-different-phone',
      }),
    ).rejects.toThrow(UnauthorizedException);

    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it('registers as phoneVerified=false when the Admin SDK is unconfigured, even with a token present', async () => {
    // PhoneTokenVerifierService itself returns { verified: false } (not a
    // throw) when the Admin SDK isn't configured — see FirebaseAdminModule.
    phoneTokenVerifier.verifyPhoneToken.mockResolvedValue({ verified: false });

    const user = await service.register({
      phone: '+2250700000013',
      role: UserRole.CLIENT,
      firebaseIdToken: 'some-token',
    });

    expect(user.phoneVerified).toBe(false);
  });

  it('creates a craftsman profile with the service category and id card key', async () => {
    await service.register({
      phone: '+2250700000014',
      role: UserRole.CRAFTSMAN,
      serviceCategory: 'plumber' as never,
      idCardStorageKey: 'id-cards/abc.png',
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
