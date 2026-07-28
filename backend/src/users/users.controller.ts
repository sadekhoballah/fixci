import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { UsersService } from './users.service';
import { RegisterUserDto } from './dto/register-user.dto';
import { UpdateFcmTokenDto } from './dto/update-fcm-token.dto';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { UserRole } from '../database/enums/user-role.enum';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post('register')
  async register(@Body() dto: RegisterUserDto) {
    const user = await this.usersService.register(dto);
    return {
      id: user.id,
      phone: user.phone,
      fullName: user.fullName,
      role: user.role,
      phoneVerified: user.phoneVerified,
    };
  }

  // Lets a client confirm a locally-cached session still corresponds to a
  // real account — e.g. the mobile splash screen re-checks this on every
  // launch, since a role cached in SharedPreferences means nothing on its
  // own if the account was deleted server-side since the last launch. Only
  // ever looks up the caller's own (token-verified) phone number — never an
  // arbitrary one — so this can't be used to enumerate other accounts.
  @Get('lookup')
  @UseGuards(FirebaseAuthGuard)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  async lookup(@Req() request: Request) {
    const user = await this.usersService.findByPhone(request.authPhone!);
    if (!user) {
      throw new NotFoundException('No account with this phone number');
    }
    const subscriptionTier =
      user.role === UserRole.CRAFTSMAN
        ? await this.usersService.findCraftsmanTier(user.id)
        : null;
    return {
      id: user.id,
      phone: user.phone,
      fullName: user.fullName,
      role: user.role,
      phoneVerified: user.phoneVerified,
      subscriptionTier,
    };
  }

  // Called on every app launch once logged in, and again whenever FCM hands
  // the app a refreshed token — see PushNotificationService on mobile.
  // AuthGuard (not just FirebaseAuthGuard) because this needs an existing
  // account to attach the token to.
  @Post('me/fcm-token')
  @UseGuards(AuthGuard)
  async updateFcmToken(
    @CurrentUser() user: { id: string },
    @Body() dto: UpdateFcmTokenDto,
  ) {
    await this.usersService.updateFcmToken(user.id, dto.fcmToken);
    return { ok: true };
  }
}
