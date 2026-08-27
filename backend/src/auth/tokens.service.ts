import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { User } from '../database/entities/user.entity';

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '30d';
const REGISTRATION_TOKEN_TTL = '15m';

export interface AccessTokenPayload {
  sub: string;
  phone: string;
  role: string;
}

export interface RefreshTokenPayload {
  sub: string;
  type: 'refresh';
}

export interface RegistrationTokenPayload {
  phone: string;
  purpose: 'register';
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

// The one place that ever mints or checks one of our own JWTs — three kinds
// (access/refresh/registration), distinguished by which secret signed them
// (so a token minted for one purpose can never be replayed as another)
// rather than by a shared secret plus a discriminator field alone.
// AdminJwtGuard/AdminAuthService have their own separate JwtService+secret
// (admin_users is a different account space entirely) — this one is for
// phone-verified client/craftsman sessions.
@Injectable()
export class TokensService {
  constructor(private readonly jwtService: JwtService) {}

  private get accessSecret(): string {
    return process.env.JWT_ACCESS_SECRET ?? 'dev-insecure-access-secret';
  }

  private get refreshSecret(): string {
    return process.env.JWT_REFRESH_SECRET ?? 'dev-insecure-refresh-secret';
  }

  // Deliberately not just accessSecret: a registration token has a
  // different shape (phone/purpose, no sub/role) than an access token
  // (sub/phone/role). Signing it with a derived-but-distinct key means a
  // registration token can never verify as an access token even if a
  // caller tried to replay one as a bearer token — the signature itself
  // would fail verifyAccessToken, not just a payload-shape check.
  private get registrationSecret(): string {
    return `${this.accessSecret}:registration`;
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

  // Short-lived proof that POST /auth/otp/check approved this exact phone
  // and no account exists for it yet — POST /users/register consumes it so
  // the caller doesn't go through OTP twice just to create their account.
  async issueRegistrationToken(phone: string): Promise<string> {
    const payload: RegistrationTokenPayload = { phone, purpose: 'register' };
    return this.jwtService.signAsync(payload, {
      secret: this.registrationSecret,
      expiresIn: REGISTRATION_TOKEN_TTL,
    });
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

  // Confirms a registration token is genuine AND was issued for exactly the
  // phone being registered — the same "don't trust a client-supplied claim"
  // shape the old OTP flow relied on.
  async verifyRegistrationToken(
    token: string,
    expectedPhone: string,
  ): Promise<void> {
    let payload: RegistrationTokenPayload;
    try {
      payload = await this.jwtService.verifyAsync<RegistrationTokenPayload>(
        token,
        { secret: this.registrationSecret },
      );
    } catch {
      throw new UnauthorizedException('Invalid or expired registration token');
    }
    if (payload.purpose !== 'register' || payload.phone !== expectedPhone) {
      throw new UnauthorizedException(
        'Registration token does not match the phone number being registered',
      );
    }
  }
}
