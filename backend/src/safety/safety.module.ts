import { Module } from '@nestjs/common';
import { SafetyController } from './safety.controller';
import { SafetyService } from './safety.service';

// No TypeOrmModule.forFeature — SafetyService goes through DataSource/raw
// SQL exclusively, same rationale as MissionsModule. Exported so
// MissionsModule (apply/select/browse enforcement), MatchingModule
// (real-time candidate filtering) and AdminModule (Signalements queue) can
// all inject SafetyService without duplicating its queries.
@Module({
  controllers: [SafetyController],
  providers: [SafetyService],
  exports: [SafetyService],
})
export class SafetyModule {}
