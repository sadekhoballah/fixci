import { Body, Controller, Post } from '@nestjs/common';
import { UsersService } from './users.service';
import { RegisterUserDto } from './dto/register-user.dto';

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
}
