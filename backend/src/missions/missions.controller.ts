import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { MissionsService } from './missions.service';
import { MatchingGateway } from '../matching/matching.gateway';
import { CreateMissionDto } from './dto/create-mission.dto';
import { UpdateMissionDto } from './dto/update-mission.dto';
import { BrowseMissionsQueryDto } from './dto/browse-missions-query.dto';
import { MineMissionsQueryDto } from './dto/mine-missions-query.dto';
import { ApplyToMissionDto } from './dto/apply-to-mission.dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth-request';

const DEFAULT_LIMIT = 20;

@Controller('missions')
@UseGuards(AuthGuard)
export class MissionsController {
  constructor(
    private readonly missionsService: MissionsService,
    private readonly matchingGateway: MatchingGateway,
  ) {}

  // Either role can post — no UserRole check, unlike MatchingController's
  // "only clients can create service requests" (Missions is deliberately
  // symmetric).
  @Post()
  async create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateMissionDto,
  ) {
    return this.missionsService.createMission(user.id, dto);
  }

  @Get()
  async browse(@Query() query: BrowseMissionsQueryDto) {
    const limit = query.limit ?? DEFAULT_LIMIT;
    const items = await this.missionsService.browseMissions(
      query,
      limit,
      query.offset ?? 0,
    );
    return { items, hasMore: items.length === limit };
  }

  @Get('mine')
  async mine(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: MineMissionsQueryDto,
  ) {
    const limit = query.limit ?? DEFAULT_LIMIT;
    const items = await this.missionsService.getMyMissions(
      user.id,
      limit,
      query.offset ?? 0,
    );
    return { items, hasMore: items.length === limit };
  }

  @Get(':id')
  async detail(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('latitude') latitude?: string,
    @Query('longitude') longitude?: string,
  ) {
    return this.missionsService.getMissionDetail(
      id,
      user.id,
      latitude !== undefined ? Number(latitude) : undefined,
      longitude !== undefined ? Number(longitude) : undefined,
    );
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMissionDto,
  ) {
    await this.missionsService.updateMission(id, user.id, dto);
    return { id, status: 'pending_moderation' };
  }

  @Patch(':id/withdraw')
  async withdraw(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.missionsService.withdrawMission(id, user.id);
    return { id, status: 'archived' };
  }

  @Post(':id/applications')
  async apply(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ApplyToMissionDto,
  ) {
    const result = await this.missionsService.applyToMission(id, user.id, dto);
    void this.matchingGateway.notifyUser(
      result.posterId,
      'mission:application:new',
      { missionId: id, applicationId: result.applicationId },
      {
        title: 'Nouvelle candidature',
        body: 'Quelqu’un s’est proposé pour votre mission.',
      },
    );
    return { applicationId: result.applicationId, status: 'pending' };
  }

  @Get(':id/applications')
  async applicants(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    const items = await this.missionsService.getApplicants(id, user.id);
    return { items };
  }

  @Patch(':id/applications/:applicationId/select')
  async select(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('applicationId', ParseUUIDPipe) applicationId: string,
  ) {
    const result = await this.missionsService.selectApplicant(
      id,
      user.id,
      applicationId,
    );
    // Only the selected applicant is notified — never the rest of the pool.
    // See the push-flood lesson from commit 129fc36 (taxi/camion).
    void this.matchingGateway.notifyUser(
      result.applicantId,
      'mission:selected',
      { missionId: id },
      {
        title: 'Vous avez été sélectionné',
        body: 'Le propriétaire de la mission vous a choisi.',
      },
    );
    return { id, status: 'in_progress' };
  }

  @Patch(':id/complete')
  async complete(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    const result = await this.missionsService.completeMission(id, user.id);
    if (result.selectedApplicantId) {
      void this.matchingGateway.notifyUser(
        result.selectedApplicantId,
        'mission:completed',
        { missionId: id },
        {
          title: 'Mission terminée',
          body: 'La mission a été marquée comme terminée.',
        },
      );
    }
    return { id, status: 'completed' };
  }
}
