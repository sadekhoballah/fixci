import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { District } from '../database/entities/district.entity';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { DistrictsService } from './districts.service';
import { DistrictsController } from './districts.controller';
import { AdminDistrictsController } from './admin-districts.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([District, User, CraftsmanProfile, ClientProfile]),
  ],
  controllers: [DistrictsController, AdminDistrictsController],
  providers: [DistrictsService],
  exports: [DistrictsService],
})
export class DistrictsModule {}
