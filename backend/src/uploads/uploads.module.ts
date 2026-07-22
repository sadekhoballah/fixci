import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { UploadsController } from './uploads.controller';

@Module({
  imports: [TypeOrmModule.forFeature([CraftsmanProfile, ClientProfile])],
  controllers: [UploadsController],
})
export class UploadsModule {}
