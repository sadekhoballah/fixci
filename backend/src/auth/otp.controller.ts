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
import { TokensService } from './tokens.service';
import { OtpThrottleService } from './otp-throttle.service';
import { TwilioVerifyService } from './twilio-verify.service';
import { StartOtpDto } from './dto/start-otp.dto';
import { CheckOtpDto } from './dto/check-otp.dto';

const CHECK_ERROR_MESSAGE: Record<
  'invalid' | 'expired' | 'too_many_attempts',
  string
> = {
  invalid: 'Incorrect code',
  expired: 'Code expired or not found — request a new one',
  too_many_attempts: 'Too many incorrect attempts — request a new code',
};

// Phone OTP for first-time registration, via Twilio Verify. Every path that
// used to go through POST /auth/reconnect (which trusted an unproven phone
// number) now goes through here instead: /otp/check returns a full session
// for an existing account, or a short-lived registrationToken for a
// brand-new one.
@Controller('auth')
export class OtpController {
  constructor(
    private readonly twilioVerify: TwilioVerifyService,
    private readonly throttle: OtpThrottleService,
    private readonly tokensService: TokensService,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    @InjectRepository(BlacklistedPhone)
    private readonly blacklistedPhoneRepository: Repository<BlacklistedPhone>,
  ) {}

  // Coarse framework guard on top of the real per-phone limits in
  // OtpThrottleService (60s cooldown, 3/hour, the 5-min / 24-h ladder).
  @Post('otp/start')
  @Throttle({ default: { limit: 5, ttl: 300_000 } })
  async start(@Body() dto: StartOtpDto): Promise<{
    status: 'sent';
    channel: 'whatsapp' | 'sms';
  }> {
    const blacklisted = await this.blacklistedPhoneRepository.findOne({
      where: { phone: dto.phone },
    });
    if (blacklisted) {
      throw new ForbiddenException('This phone number cannot be used');
    }

    await this.throttle.assertCanSend(dto.phone);
    const channel = this.twilioVerify.resolveChannel(dto.channel);
    await this.twilioVerify.startVerification(dto.phone, channel);
    await this.throttle.recordSend(dto.phone);
    return { status: 'sent', channel };
  }

  @Post('otp/check')
  @Throttle({ default: { limit: 10, ttl: 300_000 } })
  async check(@Body() dto: CheckOtpDto) {
    await this.throttle.assertCanCheck(dto.phone);

    const result = await this.twilioVerify.checkVerification(
      dto.phone,
      dto.code,
    );
    if (result !== 'approved') {
      await this.throttle.recordFailedCode(dto.phone);
      throw new UnauthorizedException(CHECK_ERROR_MESSAGE[result]);
    }
    await this.throttle.recordSuccess(dto.phone);

    const user = await this.userRepository.findOne({
      where: { phone: dto.phone },
    });
    if (user && !user.deletedAt) {
      const tokens = await this.tokensService.issueTokens(user);
      // Mirrors GET /users/lookup: the mobile client needs the craftsman's
      // subscription tier up front to route straight to their dashboard
      // instead of back through tier selection.
      const subscriptionTier =
        user.role === UserRole.CRAFTSMAN
          ? ((
              await this.craftsmanProfileRepository.findOne({
                where: { userId: user.id },
              })
            )?.subscriptionTier ?? null)
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

    const registrationToken = await this.tokensService.issueRegistrationToken(
      dto.phone,
    );
    return { status: 'new' as const, registrationToken };
  }
}
