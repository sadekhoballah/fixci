import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { District } from '../database/entities/district.entity';
import { BlacklistModule } from '../blacklist/blacklist.module';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, ClientProfile, CraftsmanProfile, District]),
    BlacklistModule,
  ],
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}
