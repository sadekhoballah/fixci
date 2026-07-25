import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { MatchingController } from './matching.controller';
import { MatchingService } from './matching.service';
import { MatchingGateway } from './matching.gateway';
import { PresenceService } from './presence.service';

@Module({
  imports: [TypeOrmModule.forFeature([User, CraftsmanProfile])],
  controllers: [MatchingController],
  providers: [MatchingService, MatchingGateway, PresenceService],
  exports: [PresenceService],
})
export class MatchingModule {}
