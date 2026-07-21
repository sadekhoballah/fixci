import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'crypto';
import { Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { SubscriptionPayment } from '../database/entities/subscription-payment.entity';
import { UserRole } from '../database/enums/user-role.enum';
import {
  SUBSCRIPTION_TIER_PRICE_CFA,
  SubscriptionTier,
} from '../database/enums/subscription-tier.enum';
import { PaymentStatus } from '../database/enums/payment-status.enum';
import { SubscribeDto } from './dto/subscribe.dto';
import { WaveWebhookDto } from './dto/wave-webhook.dto';
import { WAVE_CLIENT } from './wave/wave-client';
import type { WaveClient } from './wave/wave-client';

const SUBSCRIPTION_DURATION_DAYS = 30;

@Injectable()
export class PaymentsService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    @InjectRepository(SubscriptionPayment)
    private readonly paymentRepository: Repository<SubscriptionPayment>,
    @Inject(WAVE_CLIENT) private readonly waveClient: WaveClient,
  ) {}

  async subscribe(
    dto: SubscribeDto,
  ): Promise<{ reference: string; status: PaymentStatus }> {
    if (dto.tier === SubscriptionTier.FREE) {
      throw new BadRequestException(
        'The free tier does not go through payment',
      );
    }

    const user = await this.userRepository.findOne({
      where: { phone: dto.phone },
    });
    if (!user || user.role !== UserRole.CRAFTSMAN) {
      throw new NotFoundException(
        'No craftsman account with this phone number',
      );
    }

    const payment = await this.paymentRepository.save(
      this.paymentRepository.create({
        userId: user.id,
        tier: dto.tier,
        amountCfa: SUBSCRIPTION_TIER_PRICE_CFA[dto.tier],
        phone: dto.phone,
        reference: `FIXPRO-${randomUUID().slice(0, 8).toUpperCase()}`,
      }),
    );

    const { providerRef } = await this.waveClient.requestCharge({
      phone: payment.phone,
      amountCfa: payment.amountCfa,
      reference: payment.reference,
    });
    if (providerRef) {
      await this.paymentRepository.update(payment.id, {
        providerTransactionId: providerRef,
      });
    }

    return { reference: payment.reference, status: payment.status };
  }

  async getStatus(reference: string): Promise<{
    reference: string;
    status: PaymentStatus;
    tier: SubscriptionTier;
  }> {
    const payment = await this.findByReference(reference);
    return {
      reference: payment.reference,
      status: payment.status,
      tier: payment.tier,
    };
  }

  // Idempotent by design: Wave (or a test curl) may call this more than
  // once for the same reference, and a payment that's already resolved
  // should just no-op rather than re-activate/re-extend the subscription.
  async handleWaveWebhook(
    dto: WaveWebhookDto,
  ): Promise<{ status: PaymentStatus }> {
    const payment = await this.findByReference(dto.reference);
    if (payment.status !== PaymentStatus.PENDING) {
      return { status: payment.status };
    }

    const resolvedStatus =
      dto.status === 'success' ? PaymentStatus.SUCCESS : PaymentStatus.FAILED;

    await this.paymentRepository.update(payment.id, {
      status: resolvedStatus,
      providerTransactionId: dto.transactionId ?? payment.providerTransactionId,
    });

    if (resolvedStatus === PaymentStatus.SUCCESS) {
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + SUBSCRIPTION_DURATION_DAYS);
      await this.craftsmanProfileRepository.update(
        { userId: payment.userId },
        { subscriptionTier: payment.tier, subscriptionExpiresAt: expiresAt },
      );
    }

    return { status: resolvedStatus };
  }

  private async findByReference(
    reference: string,
  ): Promise<SubscriptionPayment> {
    const payment = await this.paymentRepository.findOne({
      where: { reference },
    });
    if (!payment) {
      throw new NotFoundException('No payment with this reference');
    }
    return payment;
  }
}
