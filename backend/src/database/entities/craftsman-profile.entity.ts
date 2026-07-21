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

  @Column({
    name: 'id_card_storage_key',
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  idCardStorageKey: string | null;

  @Column({ name: 'id_verified', type: 'boolean', default: false })
  idVerified: boolean;

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

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
