import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from './user.entity';
import { ServiceCategory } from '../enums/service-category.enum';
import { SubscriptionTier } from '../enums/subscription-tier.enum';
import type { StoredIdDocAnalysis } from '../../uploads/id-document-check';

@Entity('craftsman_profiles')
export class CraftsmanProfile {
  @PrimaryColumn('uuid', { name: 'user_id' })
  userId: string;

  @OneToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({
    name: 'service_category',
    type: 'enum',
    enum: ServiceCategory,
    enumName: 'service_category_enum',
  })
  serviceCategory: ServiceCategory;

  @Column({ name: 'experience_details', type: 'text', nullable: true })
  experienceDetails: string | null;

  // Only ever populated when serviceCategory === OTHER_TRADE — the free-text
  // trade name typed at registration in place of a fixed category (see
  // register-user.dto.ts). Null for every other category.
  @Column({
    name: 'free_trade_name',
    type: 'varchar',
    length: 120,
    nullable: true,
  })
  freeTradeName: string | null;

  @Column({
    name: 'id_card_storage_key',
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  idCardStorageKey: string | null;

  @Column({ name: 'id_verified', type: 'boolean', default: false })
  idVerified: boolean;

  // Google Vision auto-check verdict captured when the ID photo was uploaded
  // (uploads/id-document-check.ts), copied here at registration / resubmit.
  // Advisory only — it never gates anything, it just pre-scores the manual
  // review queue. Null when the upload predated the feature, the Redis
  // hand-off lapsed, or Vision was unconfigured/unreachable.
  @Column({ name: 'id_auto_check', type: 'jsonb', nullable: true })
  idAutoCheck: StoredIdDocAnalysis | null;

  // Set by AdminService.deactivateCraftsman when an admin rejects the KYC
  // submission — shown back to the craftsman alongside the "rejected,
  // please resubmit" state so they know what to fix.
  @Column({ name: 'id_rejection_reason', type: 'text', nullable: true })
  idRejectionReason: string | null;

  // Second KYC document, only ever populated for ServiceCategory.TAXI /
  // CAMION (see register-user.dto.ts) — mirrors the idCard* triplet above
  // exactly. PresenceService.setOnline gates going online for those two
  // categories on idVerified AND licenseVerified both being true.
  @Column({
    name: 'license_storage_key',
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  licenseStorageKey: string | null;

  @Column({ name: 'license_verified', type: 'boolean', default: false })
  licenseVerified: boolean;

  // Auto-check counterpart to idAutoCheck above, for the taxi/camion license
  // document. Null for every other category.
  @Column({ name: 'license_auto_check', type: 'jsonb', nullable: true })
  licenseAutoCheck: StoredIdDocAnalysis | null;

  @Column({ name: 'license_rejection_reason', type: 'text', nullable: true })
  licenseRejectionReason: string | null;

  // PostGIS geography(Point,4326); TypeORM round-trips this as raw EWKB hex on
  // plain find/save, so reads/writes that need coordinates go through raw
  // ST_ functions (ST_AsGeoJSON/ST_SetSRID) via the query builder instead.
  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  location: string | null;

  @Column({
    name: 'average_rating',
    type: 'numeric',
    precision: 3,
    scale: 2,
    nullable: true,
  })
  averageRating: string | null;

  @Column({ name: 'ratings_count', type: 'integer', default: 0 })
  ratingsCount: number;

  @Column({
    name: 'subscription_tier',
    type: 'enum',
    enum: SubscriptionTier,
    enumName: 'subscription_tier_enum',
    default: SubscriptionTier.FREE,
  })
  subscriptionTier: SubscriptionTier;

  @Column({
    name: 'subscription_expires_at',
    type: 'timestamptz',
    nullable: true,
  })
  subscriptionExpiresAt: Date | null;

  @Column({ name: 'is_available', type: 'boolean', default: false })
  isAvailable: boolean;

  // Admin kill switch (see AdminService.deactivateCraftsman) — distinct from
  // isAvailable, which the craftsman toggles themselves. A deactivated
  // craftsman can never go online again (PresenceService.setOnline refuses),
  // regardless of what they do with the availability toggle client-side.
  @Column({ name: 'is_active', type: 'boolean', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
