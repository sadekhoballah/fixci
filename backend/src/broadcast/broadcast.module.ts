import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { BroadcastNotification } from '../database/entities/broadcast-notification.entity';
import { BroadcastService } from './broadcast.service';
import { AdminBroadcastController } from './admin-broadcast.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, CraftsmanProfile, BroadcastNotification]),
  ],
  controllers: [AdminBroadcastController],
  providers: [BroadcastService],
})
export class BroadcastModule {}
