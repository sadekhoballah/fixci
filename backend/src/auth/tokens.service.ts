import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { User } from '../database/entities/user.entity';

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '30d';

export interface AccessTokenPayload {
  sub: string;
  phone: string;
  role: string;
}

export interface RefreshTokenPayload {
  sub: string;
  type: 'refresh';
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

// The one place that ever mints or checks one of our own JWTs — two kinds
// (access/refresh), distinguished by which secret signed them (so a token
// minted for one purpose can never be replayed as another) rather than by a
// shared secret plus a discriminator field alone. AdminJwtGuard/
// AdminAuthService have their own separate JwtService+secret (admin_users is
// a different account space entirely) — this one is for client/craftsman
// sessions. There used to be a third kind, a registration token proving OTP
// verification (see git history around AddPhoneVerifiedToUsers) — dropped
// along with OTP verification itself; POST /users/register no longer needs
// proof of anything beyond the phone number it's given.
@Injectable()
export class TokensService {
  constructor(private readonly jwtService: JwtService) {}

  private get accessSecret(): string {
    return process.env.JWT_ACCESS_SECRET ?? 'dev-insecure-access-secret';
  }

  private get refreshSecret(): string {
    return process.env.JWT_REFRESH_SECRET ?? 'dev-insecure-refresh-secret';
  }

  async issueTokens(
    user: Pick<User, 'id' | 'phone' | 'role'>,
  ): Promise<TokenPair> {
    const accessPayload: AccessTokenPayload = {
      sub: user.id,
      phone: user.phone!,
      role: user.role,
    };
    const refreshPayload: RefreshTokenPayload = {
      sub: user.id,
      type: 'refresh',
    };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(accessPayload, {
        secret: this.accessSecret,
        expiresIn: ACCESS_TOKEN_TTL,
      }),
      this.jwtService.signAsync(refreshPayload, {
        secret: this.refreshSecret,
        expiresIn: REFRESH_TOKEN_TTL,
      }),
    ]);
    return { accessToken, refreshToken };
  }

  async verifyAccessToken(token: string): Promise<AccessTokenPayload> {
    try {
      return await this.jwtService.verifyAsync<AccessTokenPayload>(token, {
        secret: this.accessSecret,
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired access token');
    }
  }

  async verifyRefreshToken(token: string): Promise<RefreshTokenPayload> {
    let payload: RefreshTokenPayload;
    try {
      payload = await this.jwtService.verifyAsync<RefreshTokenPayload>(token, {
        secret: this.refreshSecret,
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }
    if (payload.type !== 'refresh') {
      throw new UnauthorizedException('Not a refresh token');
    }
    return payload;
  }
}
