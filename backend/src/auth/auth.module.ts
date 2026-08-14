import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { AccessTokenGuard } from './access-token.guard';
import { AuthGuard } from './auth.guard';
import { TokensService } from './tokens.service';
import { ReconnectController } from './reconnect.controller';

// Global, like FirebaseAdminModule: every feature module needs these guards,
// and there's nothing route-specific to configure per-module.
@Global()
@Module({
  imports: [
    TypeOrmModule.forFeature([User, CraftsmanProfile]),
    // No default secret registered — TokensService always passes its own
    // secret per call (access/refresh each sign with a different one, see
    // tokens.service.ts), so there's nothing to configure here beyond
    // making JwtService injectable.
    JwtModule.register({}),
  ],
  controllers: [ReconnectController],
  providers: [AccessTokenGuard, AuthGuard, TokensService],
  // TypeOrmModule is re-exported too: AuthGuard depends on the User
  // repository, and a class passed to @UseGuards() is resolved from the
  // consuming module's own injector — being @Global() makes AuthGuard's
  // *token* visible everywhere, but its dependency still needs to resolve,
  // so the repository provider needs to be visible everywhere too.
  exports: [TypeOrmModule, AccessTokenGuard, AuthGuard, TokensService],
})
export class AuthModule {}
