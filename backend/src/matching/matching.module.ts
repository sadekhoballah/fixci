import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { DistrictsModule } from '../districts/districts.module';
import { SafetyModule } from '../safety/safety.module';
import { MatchingController } from './matching.controller';
import { MatchingService } from './matching.service';
import { MatchingGateway } from './matching.gateway';
import { PresenceService } from './presence.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, CraftsmanProfile]),
    DistrictsModule,
    SafetyModule,
  ],
  controllers: [MatchingController],
  providers: [MatchingService, MatchingGateway, PresenceService],
  exports: [PresenceService, MatchingService, MatchingGateway],
})
export class MatchingModule {}
