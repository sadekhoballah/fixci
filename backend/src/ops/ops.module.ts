import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { ServiceRequest } from '../database/entities/service-request.entity';
import { MatchingModule } from '../matching/matching.module';
import { OpsService } from './ops.service';
import { AdminOpsController } from './admin-ops.controller';

@Module({
  imports: [TypeOrmModule.forFeature([User, ServiceRequest]), MatchingModule],
  controllers: [AdminOpsController],
  providers: [OpsService],
})
export class OpsModule {}
