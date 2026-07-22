import {
  Body,
  ConflictException,
  Controller,
  ForbiddenException,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CreateServiceRequestDto } from './dto/create-service-request.dto';
import { MatchingService } from './matching.service';
import { MatchingGateway } from './matching.gateway';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth-request';
import { UserRole } from '../database/enums/user-role.enum';

@Controller('matching')
@UseGuards(AuthGuard)
export class MatchingController {
  constructor(
    private readonly matchingService: MatchingService,
    private readonly matchingGateway: MatchingGateway,
  ) {}

  @Post('requests')
  async createRequest(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateServiceRequestDto,
  ) {
    if (user.role !== UserRole.CLIENT) {
      throw new ForbiddenException('Only clients can create service requests');
    }

    const request = await this.matchingService.createServiceRequest(
      user.id,
      dto.serviceCategory,
      dto.latitude,
      dto.longitude,
    );

    void this.matchingGateway.runMatchingLoop(request);

    return { requestId: request.id, status: 'pending' };
  }

  @Patch('requests/:id/start')
  async startRequest(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    this.requireCraftsman(user);
    const result = await this.matchingService.startJob(id, user.id);
    if (!result) {
      throw new ConflictException(
        'This job cannot be started (not assigned to you, or already started)',
      );
    }
    this.matchingGateway.notifyClient(result.clientId, 'request:started', {
      requestId: id,
    });
    return { requestId: id, status: 'in_progress' };
  }

  @Patch('requests/:id/complete')
  async completeRequest(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    this.requireCraftsman(user);
    const result = await this.matchingService.completeJob(id, user.id);
    if (!result) {
      throw new ConflictException(
        'This job cannot be completed (not in progress, or not yours)',
      );
    }
    this.matchingGateway.notifyClient(result.clientId, 'request:completed', {
      requestId: id,
    });
    return { requestId: id, status: 'completed' };
  }

  @Patch('requests/:id/cancel')
  async cancelRequest(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    this.requireCraftsman(user);
    const result = await this.matchingService.cancelJob(id, user.id);
    if (!result) {
      throw new ConflictException(
        'This job cannot be cancelled (already finished, or not yours)',
      );
    }
    this.matchingGateway.notifyClient(result.clientId, 'request:cancelled', {
      requestId: id,
    });
    return { requestId: id, status: 'cancelled' };
  }

  private requireCraftsman(user: AuthenticatedUser): void {
    if (user.role !== UserRole.CRAFTSMAN) {
      throw new ForbiddenException('Only craftsmen can manage job status');
    }
  }
}
