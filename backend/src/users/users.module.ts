import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [TypeOrmModule.forFeature([User, ClientProfile, CraftsmanProfile])],
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}
