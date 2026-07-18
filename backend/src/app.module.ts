import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { appDataSourceOptions } from './config/data-source';
import { RedisModule } from './redis/redis.module';
import { MatchingModule } from './matching/matching.module';
import { UsersModule } from './users/users.module';
import { UploadsModule } from './uploads/uploads.module';
import { FirebaseAdminModule } from './firebase/firebase-admin.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRoot(appDataSourceOptions),
    RedisModule,
    MatchingModule,
    UsersModule,
    UploadsModule,
    FirebaseAdminModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
