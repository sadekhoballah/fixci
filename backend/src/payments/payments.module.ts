import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { SubscriptionPayment } from '../database/entities/subscription-payment.entity';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { WAVE_CLIENT } from './wave/wave-client';
import { StubWaveClient } from './wave/stub-wave-client';
import { WHISH_CLIENT } from './whish/whish-client';
import { StubWhishClient } from './whish/stub-whish-client';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, CraftsmanProfile, SubscriptionPayment]),
  ],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    { provide: WAVE_CLIENT, useClass: StubWaveClient },
    { provide: WHISH_CLIENT, useClass: StubWhishClient },
  ],
})
export class PaymentsModule {}
