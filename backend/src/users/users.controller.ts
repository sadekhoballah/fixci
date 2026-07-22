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
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

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
    return {
      id: user.id,
      phone: user.phone,
      fullName: user.fullName,
      role: user.role,
      phoneVerified: user.phoneVerified,
    };
  }
}
