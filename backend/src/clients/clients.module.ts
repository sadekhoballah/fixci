import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { ClientsController } from './clients.controller';
import { ClientsService } from './clients.service';

@Module({
  imports: [TypeOrmModule.forFeature([User, ClientProfile])],
  controllers: [ClientsController],
  providers: [ClientsService],
})
export class ClientsModule {}
