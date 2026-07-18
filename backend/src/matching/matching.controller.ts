import { Body, Controller, Post } from '@nestjs/common';
import { CreateServiceRequestDto } from './dto/create-service-request.dto';
import { MatchingService } from './matching.service';
import { MatchingGateway } from './matching.gateway';

@Controller('matching')
export class MatchingController {
  constructor(
    private readonly matchingService: MatchingService,
    private readonly matchingGateway: MatchingGateway,
  ) {}

  @Post('requests')
  async createRequest(@Body() dto: CreateServiceRequestDto) {
    const request = await this.matchingService.createServiceRequest(
      dto.clientId,
      dto.serviceCategory,
      dto.latitude,
      dto.longitude,
    );

    void this.matchingGateway.runMatchingLoop(request);

    return { requestId: request.id, status: 'pending' };
  }
}
