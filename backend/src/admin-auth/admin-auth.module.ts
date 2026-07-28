import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { AdminUser } from '../database/entities/admin-user.entity';
import { AdminAuthService } from './admin-auth.service';
import { AdminAuthController } from './admin-auth.controller';
import { AdminJwtGuard } from '../auth/admin-jwt.guard';

// Global, like AuthModule: AdminJwtGuard needs to be usable via @UseGuards()
// from any feature module (starting with AdminController), same rationale
// as AuthModule's own @Global() comment.
@Global()
@Module({
  imports: [
    TypeOrmModule.forFeature([AdminUser]),
    JwtModule.register({
      secret: process.env.ADMIN_JWT_SECRET,
      signOptions: { expiresIn: '12h' },
    }),
  ],
  controllers: [AdminAuthController],
  providers: [AdminAuthService, AdminJwtGuard],
  exports: [TypeOrmModule, JwtModule, AdminJwtGuard],
})
export class AdminAuthModule {}
