import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { appDataSourceOptions } from './config/data-source';
import { RedisModule } from './redis/redis.module';
import { MatchingModule } from './matching/matching.module';
import { UsersModule } from './users/users.module';
import { UploadsModule } from './uploads/uploads.module';
import { FirebaseAdminModule } from './firebase/firebase-admin.module';
import { PaymentsModule } from './payments/payments.module';
import { CraftsmenModule } from './craftsmen/craftsmen.module';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRoot(appDataSourceOptions),
    ThrottlerModule.forRoot({
      throttlers: [{ ttl: 60_000, limit: 100 }],
    }),
    RedisModule,
    FirebaseAdminModule,
    AuthModule,
    MatchingModule,
    UsersModule,
    UploadsModule,
    PaymentsModule,
    CraftsmenModule,
  ],
  controllers: [AppController],
  providers: [AppService, { provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
