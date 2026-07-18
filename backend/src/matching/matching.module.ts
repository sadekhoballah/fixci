import { Module } from '@nestjs/common';
import { MatchingController } from './matching.controller';
import { MatchingService } from './matching.service';
import { MatchingGateway } from './matching.gateway';
import { PresenceService } from './presence.service';

@Module({
  controllers: [MatchingController],
  providers: [MatchingService, MatchingGateway, PresenceService],
})
export class MatchingModule {}
