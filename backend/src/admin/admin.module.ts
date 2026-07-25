import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { MatchingModule } from '../matching/matching.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [TypeOrmModule.forFeature([CraftsmanProfile]), MatchingModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
