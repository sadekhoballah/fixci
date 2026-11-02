import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from './auth.guard';
import { TokensService } from './tokens.service';
import { UserRole } from '../database/enums/user-role.enum';

function contextFor(request: object): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

describe('AuthGuard', () => {
  const user = {
    id: 'u-1',
    phone: '+2250700000001',
    role: UserRole.CLIENT,
    phoneVerified: true,
  };

  function guardFor(pv: boolean | undefined) {
    const tokensService = {
      verifyAccessToken: jest.fn().mockResolvedValue({
        sub: 'u-1',
        phone: user.phone,
        role: 'client',
        pv,
      }),
    } as unknown as TokensService;
    const userRepository = { findOne: jest.fn().mockResolvedValue(user) };
    return new AuthGuard(tokensService, userRepository as never);
  }

  const request = () => ({ headers: { authorization: 'Bearer t' } }) as never;

  it('rejects a session opened before the number was verified, once it is', async () => {
    await expect(
      guardFor(false).canActivate(contextFor(request())),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('accepts a verified session and a legacy token with no pv claim', async () => {
    const req = request() as { user?: unknown };
    await expect(guardFor(true).canActivate(contextFor(req))).resolves.toBe(
      true,
    );
    expect(req.user).toEqual(user);
    await expect(
      guardFor(undefined).canActivate(contextFor(request())),
    ).resolves.toBe(true);
  });
});
