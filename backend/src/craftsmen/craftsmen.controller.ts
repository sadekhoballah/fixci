import { Body, Controller, Get, Patch, Query, UseGuards } from '@nestjs/common';
import { CraftsmenService } from './craftsmen.service';
import { SetAvailabilityDto } from './dto/set-availability.dto';
import { ResubmitIdCardDto } from './dto/resubmit-id-card.dto';
import { GetJobHistoryQueryDto } from './dto/get-job-history-query.dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth-request';

const DEFAULT_JOB_HISTORY_LIMIT = 20;

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

  @Patch('me/id-card')
  async resubmitIdCard(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ResubmitIdCardDto,
  ) {
    await this.craftsmenService.resubmitIdCard(user.id, dto.idCardStorageKey);
    return { idCardStorageKey: dto.idCardStorageKey };
  }

  @Get('me/stats')
  getStats(@CurrentUser() user: AuthenticatedUser) {
    return this.craftsmenService.getStats(user.id);
  }

  @Get('me/active-job')
  getActiveJob(@CurrentUser() user: AuthenticatedUser) {
    return this.craftsmenService.getActiveJob(user.id);
  }

  @Get('me/jobs')
  async getJobHistory(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: GetJobHistoryQueryDto,
  ) {
    const limit = query.limit ?? DEFAULT_JOB_HISTORY_LIMIT;
    const items = await this.craftsmenService.getJobHistory(
      user.id,
      limit,
      query.offset ?? 0,
    );
    // Wrapped (rather than a bare array) so every endpoint has the same
    // "always an object" response shape, and so pagination metadata (here:
    // whether the next page is worth requesting) has somewhere to live.
    return { items, hasMore: items.length === limit };
  }
}
