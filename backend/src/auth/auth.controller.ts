import { Body, Controller, Post, UnauthorizedException } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { TokensService } from './tokens.service';
import { RefreshTokenDto } from './dto/refresh-token.dto';

// What's left of /auth/* alongside the OTP routes (see otp.controller.ts):
// refreshing an existing session's tokens. POST /auth/reconnect — which
// logged a caller into an existing account with no proof of owning the
// number — is gone; that path now goes through POST /auth/otp/check, which
// only ever hands back a session after Twilio Verify approved the code.
@Controller('auth')
export class AuthController {
  constructor(
    private readonly tokensService: TokensService,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
  ) {}

  // Every access token is 15 minutes (see tokens.service.ts) — the mobile
  // client's ApiClient calls this transparently on a 401 (see
  // _withAuthRetry/_tryRefresh in api_client.dart) rather than making the
  // user re-authenticate every 15 minutes. This is the one route that must
  // exist for *any* session — client or craftsman — to survive longer than
  // one access-token lifetime, including the splash screen's own
  // "am I still logged in" check (GET /users/lookup, guarded by
  // AccessTokenGuard, which 401s and triggers exactly this refresh once the
  // access token from registration/OTP has expired).
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
