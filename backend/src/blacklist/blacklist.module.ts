import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BlacklistedPhone } from '../database/entities/blacklisted-phone.entity';
import { BlacklistService } from './blacklist.service';
import { AdminBlacklistController } from './admin-blacklist.controller';

@Module({
  imports: [TypeOrmModule.forFeature([BlacklistedPhone])],
  controllers: [AdminBlacklistController],
  providers: [BlacklistService],
  exports: [TypeOrmModule, BlacklistService],
})
export class BlacklistModule {}
