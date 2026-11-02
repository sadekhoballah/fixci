import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { User } from '../database/entities/user.entity';
import { UserRole } from '../database/enums/user-role.enum';

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '30d';
// Clients verify their phone by OTP exactly once (at their first request,
// see the mobile guest flow) and are then never asked again — so their
// session must outlive any realistic gap between two uses of the app.
// Sliding like the craftsman one: every /auth/refresh re-issues it.
const CLIENT_REFRESH_TOKEN_TTL = '365d';
const REGISTRATION_TOKEN_TTL = '15m';

// `pv` (phone verified) is stamped on both tokens so a session opened
// *before* the number was OTP-confirmed stops working the moment it is (see
// AuthGuard and AuthController.refresh): a client registers without OTP, so
// whoever typed a number they don't own must lose that session once the
// real owner verifies it. Absent on tokens minted before this field existed
// — every such account was already verified, so absent means verified.
export interface AccessTokenPayload {
  sub: string;
  phone: string;
  role: string;
  pv?: boolean;
}

export interface RefreshTokenPayload {
  sub: string;
  type: 'refresh';
  pv?: boolean;
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
    user: Pick<User, 'id' | 'phone' | 'role' | 'phoneVerified'>,
  ): Promise<TokenPair> {
    const accessPayload: AccessTokenPayload = {
      sub: user.id,
      phone: user.phone!,
      role: user.role,
      pv: user.phoneVerified,
    };
    const refreshPayload: RefreshTokenPayload = {
      sub: user.id,
      type: 'refresh',
      pv: user.phoneVerified,
    };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(accessPayload, {
        secret: this.accessSecret,
        expiresIn: ACCESS_TOKEN_TTL,
      }),
      this.jwtService.signAsync(refreshPayload, {
        secret: this.refreshSecret,
        expiresIn:
          user.role === UserRole.CLIENT
            ? CLIENT_REFRESH_TOKEN_TTL
            : REFRESH_TOKEN_TTL,
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
