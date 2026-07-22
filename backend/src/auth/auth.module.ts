import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { FirebaseAuthGuard } from './firebase-auth.guard';
import { AuthGuard } from './auth.guard';

// Global, like FirebaseAdminModule: every feature module needs these guards,
// and there's nothing route-specific to configure per-module.
@Global()
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  providers: [FirebaseAuthGuard, AuthGuard],
  // TypeOrmModule is re-exported too: AuthGuard depends on the User
  // repository, and a class passed to @UseGuards() is resolved from the
  // consuming module's own injector — being @Global() makes AuthGuard's
  // *token* visible everywhere, but its dependency still needs to resolve,
  // so the repository provider needs to be visible everywhere too.
  exports: [TypeOrmModule, FirebaseAuthGuard, AuthGuard],
})
export class AuthModule {}
