import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { BlacklistedPhone } from '../database/entities/blacklisted-phone.entity';
import { AccessTokenGuard } from './access-token.guard';
import { AuthGuard } from './auth.guard';
import { TokensService } from './tokens.service';
import { OtpThrottleService } from './otp-throttle.service';
import { TwilioVerifyService } from './twilio-verify.service';
import { AuthController } from './auth.controller';
import { OtpController } from './otp.controller';

// Global, like FirebaseAdminModule: every feature module needs these guards,
// and there's nothing route-specific to configure per-module.
@Global()
@Module({
  imports: [
    TypeOrmModule.forFeature([User, CraftsmanProfile, BlacklistedPhone]),
    // No default secret registered — TokensService always passes its own
    // secret per call (access/refresh/registration each sign with a
    // different one, see tokens.service.ts), so there's nothing to
    // configure here beyond making JwtService injectable.
    JwtModule.register({}),
  ],
  controllers: [AuthController, OtpController],
  providers: [
    AccessTokenGuard,
    AuthGuard,
    TokensService,
    OtpThrottleService,
    TwilioVerifyService,
  ],
  // TypeOrmModule is re-exported too: AuthGuard depends on the User
  // repository, and a class passed to @UseGuards() is resolved from the
  // consuming module's own injector — being @Global() makes AuthGuard's
  // *token* visible everywhere, but its dependency still needs to resolve,
  // so the repository provider needs to be visible everywhere too.
  exports: [TypeOrmModule, AccessTokenGuard, AuthGuard, TokensService],
})
export class AuthModule {}
