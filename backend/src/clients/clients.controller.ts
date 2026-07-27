import { Body, Controller, Get, Patch, Query, UseGuards } from '@nestjs/common';
import { ClientsService } from './clients.service';
import { GetJobHistoryQueryDto } from '../craftsmen/dto/get-job-history-query.dto';
import { ResubmitIdCardDto } from '../craftsmen/dto/resubmit-id-card.dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth-request';

const DEFAULT_REQUEST_HISTORY_LIMIT = 20;

@Controller('clients')
@UseGuards(AuthGuard)
export class ClientsController {
  constructor(private readonly clientsService: ClientsService) {}

  @Get('me')
  getMe(@CurrentUser() user: AuthenticatedUser) {
    return this.clientsService.getMe(user.id);
  }

  @Patch('me/id-card')
  async resubmitIdCard(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ResubmitIdCardDto,
  ) {
    await this.clientsService.resubmitIdCard(user.id, dto.idCardStorageKey);
    return { idCardStorageKey: dto.idCardStorageKey };
  }

  @Get('me/active-request')
  getActiveRequest(@CurrentUser() user: AuthenticatedUser) {
    return this.clientsService.getActiveRequest(user.id);
  }

  @Get('me/requests')
  async getRequestHistory(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: GetJobHistoryQueryDto,
  ) {
    const limit = query.limit ?? DEFAULT_REQUEST_HISTORY_LIMIT;
    const items = await this.clientsService.getRequestHistory(
      user.id,
      limit,
      query.offset ?? 0,
    );
    return { items, hasMore: items.length === limit };
  }
}
