import {
  Body,
  Controller,
  ForbiddenException,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BlacklistedPhone } from '../database/entities/blacklisted-phone.entity';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { OtpService } from './otp.service';
import { TokensService } from './tokens.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';

const VERIFY_ERROR_MESSAGE: Record<'invalid' | 'expired' | 'too_many_attempts', string> = {
  invalid: 'Incorrect code',
  expired: 'Code expired or not found — request a new one',
  too_many_attempts: 'Too many incorrect attempts — request a new code',
};

@Controller('auth')
export class OtpController {
  constructor(
    private readonly otpService: OtpService,
    private readonly tokensService: TokensService,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(BlacklistedPhone)
    private readonly blacklistedPhoneRepository: Repository<BlacklistedPhone>,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
  ) {}

  // Tightly throttled (well below the app-wide default of 100/min) since
  // every call here spends a WhatsApp template send — bounds both cost and
  // a caller's ability to spam a phone number with codes.
  @Post('send-otp')
  @Throttle({ default: { limit: 3, ttl: 300_000 } })
  async sendOtp(@Body() dto: SendOtpDto): Promise<{ ok: true }> {
    const blacklisted = await this.blacklistedPhoneRepository.findOne({
      where: { phone: dto.phone },
    });
    if (blacklisted) {
      throw new ForbiddenException('This phone number cannot be used');
    }

    await this.otpService.requestOtp(dto.phone);
    return { ok: true };
  }

  @Post('verify-otp')
  @Throttle({ default: { limit: 10, ttl: 300_000 } })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    const result = await this.otpService.verifyOtp(dto.phone, dto.code);
    if (result !== 'valid') {
      throw new UnauthorizedException(VERIFY_ERROR_MESSAGE[result]);
    }

    const user = await this.userRepository.findOne({
      where: { phone: dto.phone },
    });
    if (user && !user.deletedAt) {
      const tokens = await this.tokensService.issueTokens(user);
      // Mirrors GET /users/lookup: the mobile client needs the craftsman's
      // subscription tier up front to route straight to their dashboard
      // instead of back through tier selection, and would otherwise have to
      // make a second round trip for it right after this one.
      const subscriptionTier =
        user.role === UserRole.CRAFTSMAN
          ? (
              await this.craftsmanProfileRepository.findOne({
                where: { userId: user.id },
              })
            )?.subscriptionTier ?? null
          : null;
      return {
        status: 'existing' as const,
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

    // No account yet for this phone — hand back a short-lived proof of
    // verification instead, so POST /users/register can trust the phone
    // without the caller having to go through OTP verification twice.
    const registrationToken = await this.tokensService.issueRegistrationToken(
      dto.phone,
    );
    return { status: 'new' as const, registrationToken };
  }

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
}
