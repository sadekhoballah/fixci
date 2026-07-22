import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { CraftsmenService } from './craftsmen.service';
import { SetAvailabilityDto } from './dto/set-availability.dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth-request';

@Controller('craftsmen')
@UseGuards(AuthGuard)
export class CraftsmenController {
  constructor(private readonly craftsmenService: CraftsmenService) {}

  @Get('me')
  getMe(@CurrentUser() user: AuthenticatedUser) {
    return this.craftsmenService.getMe(user.id);
  }

  @Patch('me/availability')
  setAvailability(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: SetAvailabilityDto,
  ) {
    return this.craftsmenService.setAvailability(user.id, dto);
  }

  @Get('me/stats')
  getStats(@CurrentUser() user: AuthenticatedUser) {
    return this.craftsmenService.getStats(user.id);
  }
}
