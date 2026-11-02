import {
  BadRequestException,
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AdminJwtGuard } from '../auth/admin-jwt.guard';
import { OpsService, OpsStatsRange } from './ops.service';
import {
  MissionHistoryQueryDto,
  RequestHistoryQueryDto,
} from './dto/ops-history-query.dto';
import { CountryFilterDto } from '../districts/dto/country-filter.dto';

const VALID_RANGES: OpsStatsRange[] = ['today', 'week', 'all'];

@Controller('admin/ops')
@UseGuards(AdminJwtGuard)
export class AdminOpsController {
  constructor(private readonly opsService: OpsService) {}

  @Get('presence')
  async getPresence(@Query() { country }: CountryFilterDto) {
    return { items: await this.opsService.getPresence(country) };
  }

  @Get('stats')
  async getStats(
    @Query() { country }: CountryFilterDto,
    @Query('range') range = 'today',
  ) {
    if (!VALID_RANGES.includes(range as OpsStatsRange)) {
      throw new BadRequestException('range must be one of: today, week, all');
    }
    return this.opsService.getStats(range as OpsStatsRange, country);
  }

  // "Missions effectuées" tab — read-only.
  @Get('missions-history')
  async getMissionHistory(@Query() query: MissionHistoryQueryDto) {
    return this.opsService.getMissionHistory(query);
  }

  // "Ops live détaillée" tab — read-only.
  @Get('requests')
  async getRequestHistory(@Query() query: RequestHistoryQueryDto) {
    return this.opsService.getRequestHistory(query);
  }
}
