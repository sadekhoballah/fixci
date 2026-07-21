import { Body, Controller, Get, Patch, Query } from '@nestjs/common';
import { CraftsmenService } from './craftsmen.service';
import { MeQueryDto } from './dto/me-query.dto';
import { SetAvailabilityDto } from './dto/set-availability.dto';

@Controller('craftsmen')
export class CraftsmenController {
  constructor(private readonly craftsmenService: CraftsmenService) {}

  @Get('me')
  getMe(@Query() query: MeQueryDto) {
    return this.craftsmenService.getMe(query.phone);
  }

  @Patch('me/availability')
  setAvailability(@Body() dto: SetAvailabilityDto) {
    return this.craftsmenService.setAvailability(dto);
  }

  @Get('me/stats')
  getStats(@Query() query: MeQueryDto) {
    return this.craftsmenService.getStats(query.phone);
  }
}
