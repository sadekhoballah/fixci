import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { MatchingModule } from '../matching/matching.module';
import { CraftsmenController } from './craftsmen.controller';
import { CraftsmenService } from './craftsmen.service';

@Module({
  imports: [TypeOrmModule.forFeature([User, CraftsmanProfile]), MatchingModule],
  controllers: [CraftsmenController],
  providers: [CraftsmenService],
})
export class CraftsmenModule {}
