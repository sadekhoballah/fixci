import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from './user.entity';
import { SubscriptionTier } from '../enums/subscription-tier.enum';
import { PaymentStatus } from '../enums/payment-status.enum';

// One row per subscription-purchase attempt, independent of whether the
// craftsman ever completed the payment — this is what a Wave webhook (or,
// for now, a manually-triggered test call) matches back against via
// `reference` to know which pending charge just resolved.
@Entity('subscription_payments')
export class SubscriptionPayment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({
    type: 'enum',
    enum: SubscriptionTier,
    enumName: 'subscription_tier_enum',
  })
  tier: SubscriptionTier;

  @Column({ name: 'amount_cfa', type: 'integer' })
  amountCfa: number;

  // Snapshotted at request time rather than joined from the user, so a
  // payment record still reflects what was actually charged even if the
  // account's phone number changes later.
  @Column({ type: 'varchar', length: 20 })
  phone: string;

  // Our own idempotency key, generated before we ever call out to Wave —
  // this is what the provider echoes back on the webhook so we can find
  // the matching row without trusting anything else in that payload.
  @Column({ type: 'varchar', length: 64, unique: true })
  reference: string;

  @Column({
    name: 'provider_transaction_id',
    type: 'varchar',
    length: 64,
    nullable: true,
  })
  providerTransactionId: string | null;

  @Column({
    type: 'enum',
    enum: PaymentStatus,
    enumName: 'payment_status_enum',
    default: PaymentStatus.PENDING,
  })
  status: PaymentStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
