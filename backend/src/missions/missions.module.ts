import { Module } from '@nestjs/common';
import { MatchingModule } from '../matching/matching.module';
import { SafetyModule } from '../safety/safety.module';
import { MissionsController } from './missions.controller';
import { MissionsService } from './missions.service';

// No TypeOrmModule.forFeature here — MissionsService goes through
// DataSource/raw SQL exclusively (see its class-level comment), same
// reasoning as MatchingService. SafetyModule backs the block-enforcement
// checks in browseMissions/applyToMission/selectApplicant.
@Module({
  imports: [MatchingModule, SafetyModule],
  controllers: [MissionsController],
  providers: [MissionsService],
})
export class MissionsModule {}
