import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Post,
  Query,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { RegisterUserDto } from './dto/register-user.dto';
import { LookupUserQueryDto } from './dto/lookup-user-query.dto';

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
  // own if the account was deleted server-side since the last launch.
  @Get('lookup')
  async lookup(@Query() query: LookupUserQueryDto) {
    const user = await this.usersService.findByPhone(query.phone);
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
