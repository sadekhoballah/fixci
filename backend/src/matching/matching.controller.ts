import {
  Body,
  Controller,
  ForbiddenException,
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
}
