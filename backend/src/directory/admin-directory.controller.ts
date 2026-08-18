import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Delete,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { AdminJwtGuard } from '../auth/admin-jwt.guard';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { DirectoryService } from './directory.service';
import { MatchingService } from '../matching/matching.service';
import { MatchingGateway } from '../matching/matching.gateway';
import { UsersService } from '../users/users.service';
import { AdminDeleteAccountDto } from './dto/admin-delete-account.dto';

@Controller('admin/directory')
@UseGuards(AdminJwtGuard)
export class AdminDirectoryController {
  constructor(
    private readonly directoryService: DirectoryService,
    private readonly matchingService: MatchingService,
    private readonly matchingGateway: MatchingGateway,
    private readonly usersService: UsersService,
  ) {}

  @Get('clients')
  async clients(@Query('search') search?: string) {
    return { items: await this.directoryService.listClients(search) };
  }

  @Get('craftsmen')
  async craftsmen(
    @Query('search') search?: string,
    @Query('category') category?: string,
  ) {
    if (
      category &&
      !Object.values(ServiceCategory).includes(category as ServiceCategory)
    ) {
      throw new BadRequestException('Invalid category');
    }
    return {
      items: await this.directoryService.listCraftsmen(
        search,
        category as ServiceCategory | undefined,
      ),
    };
  }

  // Step 1 of the admin "reset account" flow: force-cancels any mission the
  // account is currently a party to (as client or craftsman), so the
  // adminDeleteAccount call right after this doesn't hit the same "mission
  // en cours" guard the self-service deletion has. Also notifies whichever
  // counterparty was on the other side of each cancelled request, same as a
  // normal cancel would.
  @Post('users/:id/cancel-active-missions')
  async cancelActiveMissions(@Param('id', ParseUUIDPipe) id: string) {
    const cancelled = await this.matchingService.adminCancelActiveRequests(id);
    for (const request of cancelled) {
      this.matchingGateway.abortMatchingLoop(request.requestId);
      if (request.clientId === id) {
        if (request.craftsmanId) {
          this.matchingGateway.notifyCraftsman(
            request.craftsmanId,
            'request:cancelled',
            { requestId: request.requestId },
          );
          this.matchingGateway.clearActiveAssignment(request.craftsmanId);
        }
      } else {
        this.matchingGateway.notifyClient(
          request.clientId,
          'request:cancelled',
          {
            requestId: request.requestId,
          },
        );
        this.matchingGateway.clearActiveAssignment(id);
      }
    }
    return { cancelledCount: cancelled.length };
  }

  // Step 2: anonymizes the account (same irreversible path as self-service
  // deletion — see UsersService.deleteAccount) so the phone number is freed
  // for re-registration. Throws a 409 if a mission is still active; the
  // admin panel is expected to call cancel-active-missions first in that case.
  @Delete('users/:id')
  async deleteAccount(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AdminDeleteAccountDto,
    @Req() request: Request,
  ) {
    await this.usersService.adminDeleteAccount(
      id,
      request.adminUser!.id,
      dto.reason ?? null,
    );
    return { success: true };
  }
}
