import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { Mission } from '../database/entities/mission.entity';
import { MatchingModule } from '../matching/matching.module';
import { SafetyModule } from '../safety/safety.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([CraftsmanProfile, ClientProfile, Mission]),
    MatchingModule,
    SafetyModule,
  ],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
