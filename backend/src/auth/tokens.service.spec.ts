import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { UnauthorizedException } from '@nestjs/common';
import { TokensService } from './tokens.service';
import { UserRole } from '../database/enums/user-role.enum';

describe('TokensService', () => {
  let service: TokensService;
  let jwtService: { signAsync: jest.Mock; verifyAsync: jest.Mock };

  beforeEach(async () => {
    jwtService = {
      signAsync: jest.fn().mockResolvedValue('signed-token'),
      verifyAsync: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [TokensService, { provide: JwtService, useValue: jwtService }],
    }).compile();

    service = module.get(TokensService);
  });

  it('issues an access token and a refresh token signed with different secrets/TTLs', async () => {
    await service.issueTokens({
      id: 'user-1',
      phone: '+2250700000001',
      role: UserRole.CLIENT,
    });

    expect(jwtService.signAsync).toHaveBeenCalledWith(
      { sub: 'user-1', phone: '+2250700000001', role: UserRole.CLIENT },
      expect.objectContaining({ expiresIn: '15m' }),
    );
    expect(jwtService.signAsync).toHaveBeenCalledWith(
      { sub: 'user-1', type: 'refresh' },
      expect.objectContaining({ expiresIn: '30d' }),
    );
    const [, accessOpts] = jwtService.signAsync.mock.calls[0] as [
      unknown,
      { secret: string },
    ];
    const [, refreshOpts] = jwtService.signAsync.mock.calls[1] as [
      unknown,
      { secret: string },
    ];
    expect(accessOpts.secret).not.toBe(refreshOpts.secret);
  });

  it('signs a registration token with a secret distinct from the access token secret', async () => {
    await service.issueTokens({
      id: 'user-1',
      phone: '+2250700000001',
      role: UserRole.CLIENT,
    });
    const [, accessOpts] = jwtService.signAsync.mock.calls[0] as [
      unknown,
      { secret: string },
    ];

    await service.issueRegistrationToken('+2250700000002');
    const [, registrationOpts] = jwtService.signAsync.mock.calls[2] as [
      unknown,
      { secret: string },
    ];

    expect(registrationOpts.secret).not.toBe(accessOpts.secret);
  });

  it('verifyAccessToken returns the payload on success', async () => {
    const payload = { sub: 'user-1', phone: '+2250700000001', role: 'client' };
    jwtService.verifyAsync.mockResolvedValue(payload);

    await expect(service.verifyAccessToken('a-token')).resolves.toEqual(payload);
  });

  it('verifyAccessToken throws UnauthorizedException on an invalid/expired token', async () => {
    jwtService.verifyAsync.mockRejectedValue(new Error('jwt expired'));

    await expect(service.verifyAccessToken('bad-token')).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('verifyRefreshToken rejects a token that verifies but has the wrong type claim', async () => {
    jwtService.verifyAsync.mockResolvedValue({ sub: 'user-1', type: 'access' });

    await expect(service.verifyRefreshToken('not-a-refresh-token')).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('verifyRegistrationToken rejects a phone mismatch', async () => {
    jwtService.verifyAsync.mockResolvedValue({
      phone: '+2250700000001',
      purpose: 'register',
    });

    await expect(
      service.verifyRegistrationToken('token', '+2250700000099'),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('verifyRegistrationToken resolves when the phone and purpose match', async () => {
    jwtService.verifyAsync.mockResolvedValue({
      phone: '+2250700000001',
      purpose: 'register',
    });

    await expect(
      service.verifyRegistrationToken('token', '+2250700000001'),
    ).resolves.toBeUndefined();
  });
});
