import { Module } from '@nestjs/common';
import { MatchingModule } from '../matching/matching.module';
import { MissionsController } from './missions.controller';
import { MissionsService } from './missions.service';

// No TypeOrmModule.forFeature here — MissionsService goes through
// DataSource/raw SQL exclusively (see its class-level comment), same
// reasoning as MatchingService.
@Module({
  imports: [MatchingModule],
  controllers: [MissionsController],
  providers: [MissionsService],
})
export class MissionsModule {}
