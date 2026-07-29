import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { MatchingModule } from '../matching/matching.module';
import { DirectoryService } from './directory.service';
import { AdminDirectoryController } from './admin-directory.controller';

@Module({
  imports: [TypeOrmModule.forFeature([User, CraftsmanProfile]), MatchingModule],
  controllers: [AdminDirectoryController],
  providers: [DirectoryService],
})
export class DirectoryModule {}
