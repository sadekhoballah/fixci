import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'crypto';
import { DataSource, Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { SubscriptionPayment } from '../database/entities/subscription-payment.entity';
import { UserRole } from '../database/enums/user-role.enum';
import {
  Currency,
  getSubscriptionPrice,
  SubscriptionTier,
} from '../database/enums/subscription-tier.enum';
import { PaymentStatus } from '../database/enums/payment-status.enum';
import { SubscribeDto } from './dto/subscribe.dto';
import { PaymentWebhookDto } from './dto/payment-webhook.dto';
import { WAVE_CLIENT } from './wave/wave-client';
import type { WaveClient } from './wave/wave-client';
import { WHISH_CLIENT } from './whish/whish-client';
import type { WhishClient } from './whish/whish-client';
import { AuthenticatedUser } from '../auth/auth-request';

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
    @Inject(WHISH_CLIENT) private readonly whishClient: WhishClient,
    private readonly dataSource: DataSource,
  ) {}

  async subscribe(
    caller: AuthenticatedUser,
    dto: SubscribeDto,
  ): Promise<{ reference: string; status: PaymentStatus }> {
    if (dto.tier === SubscriptionTier.FREE) {
      throw new BadRequestException(
        'The free tier does not go through payment',
      );
    }

    if (caller.role !== UserRole.CRAFTSMAN) {
      throw new NotFoundException('No craftsman account for this user');
    }

    const user = await this.userRepository.findOne({
      where: { id: caller.id },
      relations: { district: true },
    });
    if (!user) {
      throw new NotFoundException('No craftsman account for this user');
    }

    const { amount, currency } = getSubscriptionPrice(
      dto.tier,
      user.district.countryCode,
    );

    const payment = await this.paymentRepository.save(
      this.paymentRepository.create({
        userId: caller.id,
        tier: dto.tier,
        amount,
        currency,
        phone: caller.phone,
        reference: `FIXPRO-${randomUUID().slice(0, 8).toUpperCase()}`,
      }),
    );

    const client =
      currency === Currency.USD ? this.whishClient : this.waveClient;
    const { providerRef } = await client.requestCharge({
      phone: payment.phone,
      amount: payment.amount,
      currency: payment.currency,
      reference: payment.reference,
    });
    if (providerRef) {
      await this.paymentRepository.update(payment.id, {
        providerTransactionId: providerRef,
      });
    }

    return { reference: payment.reference, status: payment.status };
  }

  async getStatus(
    callerId: string,
    reference: string,
  ): Promise<{
    reference: string;
    status: PaymentStatus;
    tier: SubscriptionTier;
  }> {
    const payment = await this.findByReference(reference);
    // Deliberately the same "not found" as an unknown reference — confirming
    // "this reference exists but isn't yours" would let a guessed/leaked
    // reference be used to fingerprint someone else's payment activity.
    if (payment.userId !== callerId) {
      throw new NotFoundException('No payment with this reference');
    }
    return {
      reference: payment.reference,
      status: payment.status,
      tier: payment.tier,
    };
  }

  // Idempotent by design: a provider (or a test curl) may call this more
  // than once for the same reference, and a payment that's already resolved
  // should just no-op rather than re-activate/re-extend the subscription.
  // The status flip is a single atomic UPDATE ... WHERE status = 'pending'
  // (same compare-and-swap pattern as MatchingService.tryAssign) so two
  // concurrent redeliveries for the same reference can't both slip past the
  // "still pending" check and double-apply the subscription extension.
  // Shared by both /payments/wave/webhook and /payments/whish/webhook — the
  // reference alone identifies which payment (and provider) resolved, so
  // there's nothing provider-specific left to branch on here.
  async handlePaymentWebhook(
    dto: PaymentWebhookDto,
  ): Promise<{ status: PaymentStatus }> {
    const resolvedStatus =
      dto.status === 'success' ? PaymentStatus.SUCCESS : PaymentStatus.FAILED;

    const [rows]: [
      Array<{ id: string; user_id: string; tier: SubscriptionTier }>,
      number,
    ] = await this.dataSource.query(
      `UPDATE "subscription_payments"
       SET "status" = $1, "provider_transaction_id" = COALESCE($2, "provider_transaction_id"), "updated_at" = now()
       WHERE "reference" = $3 AND "status" = 'pending'
       RETURNING "id", "user_id", "tier"`,
      [resolvedStatus, dto.transactionId ?? null, dto.reference],
    );

    if (rows.length === 0) {
      // Either the reference doesn't exist, or it was already resolved by an
      // earlier (or concurrent) delivery — both cases just no-op.
      const existing = await this.paymentRepository.findOne({
        where: { reference: dto.reference },
      });
      if (!existing) {
        throw new NotFoundException('No payment with this reference');
      }
      return { status: existing.status };
    }

    if (resolvedStatus === PaymentStatus.SUCCESS) {
      const [{ user_id: userId, tier }] = rows;
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + SUBSCRIPTION_DURATION_DAYS);
      await this.craftsmanProfileRepository.update(
        { userId },
        { subscriptionTier: tier, subscriptionExpiresAt: expiresAt },
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
