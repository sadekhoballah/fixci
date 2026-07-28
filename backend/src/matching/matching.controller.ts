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
import { CreateRatingDto } from './dto/create-rating.dto';
import { MatchingService } from './matching.service';
import { MatchingGateway } from './matching.gateway';
import { DistrictsService } from '../districts/districts.service';
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
    private readonly districtsService: DistrictsService,
  ) {}

  @Post('requests')
  async createRequest(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateServiceRequestDto,
  ) {
    if (user.role !== UserRole.CLIENT) {
      throw new ForbiddenException('Only clients can create service requests');
    }
    if (!(await this.districtsService.isClientOrderingActiveForUser(user.id))) {
      throw new ForbiddenException(
        "Le service n'est pas encore disponible dans votre zone.",
      );
    }

    const request = await this.matchingService.createServiceRequest(
      user.id,
      dto.serviceCategory,
      dto.latitude,
      dto.longitude,
    );
    if (!request) {
      throw new ConflictException('You already have an active service request');
    }

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

  // Craftsman's half of mutual completion — flips the job to
  // awaiting_client_confirmation, not completed. The client still has to
  // confirm via confirmCompleteRequest below before it's truly done.
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
    this.matchingGateway.notifyClient(
      result.clientId,
      'request:awaiting_confirmation',
      { requestId: id },
    );
    this.matchingGateway.clearActiveAssignment(user.id);
    return { requestId: id, status: 'awaiting_client_confirmation' };
  }

  // Client's half of mutual completion — only they can finalize a job the
  // craftsman has already marked done.
  @Patch('requests/:id/confirm-complete')
  async confirmCompleteRequest(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    this.requireClient(user);
    const result = await this.matchingService.confirmCompletion(id, user.id);
    if (!result) {
      throw new ConflictException(
        'This job cannot be confirmed (not awaiting your confirmation, or not yours)',
      );
    }
    this.matchingGateway.notifyCraftsman(
      result.craftsmanId,
      'request:completed',
      { requestId: id },
    );
    return { requestId: id, status: 'completed' };
  }

  @Post('requests/:id/rating')
  async rateRequest(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateRatingDto,
  ) {
    this.requireClient(user);
    const result = await this.matchingService.submitRating(
      id,
      user.id,
      dto.stars,
      dto.comment ?? null,
    );
    if (!result) {
      throw new ConflictException(
        'This job cannot be rated (not completed, not yours, or already rated)',
      );
    }
    return result;
  }

  @Patch('requests/:id/cancel')
  async cancelRequest(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    if (user.role === UserRole.CLIENT) {
      const result = await this.matchingService.cancelByClient(id, user.id);
      if (!result) {
        throw new ConflictException(
          'This request cannot be cancelled (already resolved)',
        );
      }
      if (result.craftsmanId) {
        this.matchingGateway.notifyCraftsman(
          result.craftsmanId,
          'request:cancelled',
          { requestId: id },
        );
        this.matchingGateway.clearActiveAssignment(result.craftsmanId);
      }
      return { requestId: id, status: 'cancelled' };
    }

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
    this.matchingGateway.clearActiveAssignment(user.id);
    return { requestId: id, status: 'cancelled' };
  }

  private requireCraftsman(user: AuthenticatedUser): void {
    if (user.role !== UserRole.CRAFTSMAN) {
      throw new ForbiddenException('Only craftsmen can manage job status');
    }
  }

  private requireClient(user: AuthenticatedUser): void {
    if (user.role !== UserRole.CLIENT) {
      throw new ForbiddenException('Only clients can perform this action');
    }
  }
}
