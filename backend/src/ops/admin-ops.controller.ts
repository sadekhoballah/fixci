import { BadRequestException, Controller, Get, Query, UseGuards } from '@nestjs/common';
import { AdminJwtGuard } from '../auth/admin-jwt.guard';
import { OpsService, OpsStatsRange } from './ops.service';

const VALID_RANGES: OpsStatsRange[] = ['today', 'week', 'all'];

@Controller('admin/ops')
@UseGuards(AdminJwtGuard)
export class AdminOpsController {
  constructor(private readonly opsService: OpsService) {}

  @Get('presence')
  async getPresence() {
    return { items: await this.opsService.getPresence() };
  }

  @Get('stats')
  async getStats(@Query('range') range = 'today') {
    if (!VALID_RANGES.includes(range as OpsStatsRange)) {
      throw new BadRequestException('range must be one of: today, week, all');
    }
    return this.opsService.getStats(range as OpsStatsRange);
  }
}
