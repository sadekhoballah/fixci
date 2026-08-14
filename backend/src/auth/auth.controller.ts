import {
  Body,
  Controller,
  NotFoundException,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { IsNotEmpty, Matches } from 'class-validator';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { TokensService } from './tokens.service';
import { RefreshTokenDto } from './dto/refresh-token.dto';

export class ReconnectDto {
  @IsNotEmpty()
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: 'phone must be in E.164 format, e.g. +2250700000001',
  })
  phone: string;
}

// What's left of /auth/* now that OTP is gone: refreshing an existing
// session's tokens, and (phase-1 only, see the doc comment below)
// reconnecting to an existing account from a device-sourced phone number.
// Named AuthController rather than OtpController/ReconnectController on
// purpose — neither of those names would still fit both routes.
@Controller('auth')
export class AuthController {
  constructor(
    private readonly tokensService: TokensService,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
  ) {}

  // Every access token is 15 minutes (see tokens.service.ts) — the mobile
  // client's ApiClient calls this transparently on a 401 (see
  // _withAuthRetry/_tryRefresh in api_client.dart) rather than making the
  // user re-authenticate every 15 minutes. This is the one route that must
  // exist for *any* session — client or craftsman — to survive longer than
  // one access-token lifetime, including the splash screen's own
  // "am I still logged in" check (GET /users/lookup, guarded by
  // AccessTokenGuard, which 401s and triggers exactly this refresh once the
  // access token from registration/reconnect has expired).
  @Post('refresh')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  async refresh(@Body() dto: RefreshTokenDto) {
    const payload = await this.tokensService.verifyRefreshToken(
      dto.refreshToken,
    );
    const user = await this.userRepository.findOne({
      where: { id: payload.sub },
    });
    if (!user || user.deletedAt) {
      throw new UnauthorizedException('Account no longer active');
    }
    return this.tokensService.issueTokens(user);
  }

  // Phase-1 replacement for POST /auth/verify-otp's "existing account"
  // branch, now that phone verification is gone (see RegisterUserDto —
  // there's no more registrationToken). This deliberately does NOT verify
  // the caller owns `phone` in any way — it trusts whoever calls it.
  //
  // That's a real, accepted trade-off, not an oversight: the mobile client
  // is the thing enforcing the actual trust boundary, by only ever calling
  // this after the *device* (not the user's keyboard) reported the number
  // via Android's Phone Number Hint API — see mobile's
  // core/auth/phone_hint_service.dart and the reconnect() call in
  // onboarding_repository.dart, which is gated on PhoneSource.deviceHint. A
  // manually-typed number (Android fallback with no SIM data, or iOS) never
  // reaches this endpoint — see OnboardingController.completeRegistration,
  // which shows a "contact support" message instead on a 409 from
  // POST /users/register for that case.
  //
  // This is intentionally the *only* place that trust boundary lives, so
  // that swapping the manual-entry path for real verification in phase 2
  // (WhatsApp Business API / Twilio Verify) only ever touches that one call
  // site — this endpoint's contract (and the device-hint path) doesn't need
  // to change.
  @Post('reconnect')
  @Throttle({ default: { limit: 10, ttl: 300_000 } })
  async reconnect(@Body() dto: ReconnectDto) {
    const user = await this.userRepository.findOne({
      where: { phone: dto.phone },
    });
    if (!user || user.deletedAt) {
      throw new NotFoundException('No account with this phone number');
    }

    const tokens = await this.tokensService.issueTokens(user);
    // Mirrors GET /users/lookup and the old verify-otp "existing" branch:
    // the mobile client needs the craftsman's subscription tier up front to
    // route straight to their dashboard instead of back through tier
    // selection.
    const subscriptionTier =
      user.role === UserRole.CRAFTSMAN
        ? ((
            await this.craftsmanProfileRepository.findOne({
              where: { userId: user.id },
            })
          )?.subscriptionTier ?? null)
        : null;

    return {
      ...tokens,
      user: {
        id: user.id,
        phone: user.phone,
        fullName: user.fullName,
        role: user.role,
        subscriptionTier,
      },
    };
  }
}
