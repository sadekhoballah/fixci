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
import { ServiceCategory } from '../enums/service-category.enum';
import { MissionStatus } from '../enums/mission-status.enum';
import { MissionTimingPreference } from '../enums/mission-timing-preference.enum';

// A Missions/Freelance board post. Generic user_id-keyed (posterId, not
// clientId/craftsmanId) — either a client or a craftsman can post, per the
// product decision that this board is symmetric, unlike the real-time
// matching engine (ServiceRequest).
@Entity('missions')
export class Mission {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'poster_id', type: 'uuid' })
  posterId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'poster_id' })
  poster: User;

  @Column({ type: 'varchar', length: 150 })
  title: string;

  @Column({ type: 'text' })
  description: string;

  // Free-text-adjacent browse/filter tag, not fed into the real-time
  // matching engine. Nullable: a mission doesn't have to fit one of the
  // fixed trades — that's the whole point of the board existing for
  // OTHER_TRADE work.
  @Column({
    type: 'enum',
    enum: ServiceCategory,
    enumName: 'service_category_enum',
    nullable: true,
  })
  category: ServiceCategory | null;

  // Plain text address — no map picker exists anywhere in the app
  // (google_maps_flutter is an unused dependency), same rationale as
  // ServiceRequest.destinationAddress.
  @Column({ name: 'location_address', type: 'text' })
  locationAddress: string;

  // See CraftsmanProfile.location for the raw-EWKB round-trip caveat — reads
  // and writes needing the actual coordinates go through raw ST_* SQL.
  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  location: string;

  // Up to 3, uploaded individually via POST /uploads/mission-photo before
  // mission creation. A Postgres array rather than a join table: this is a
  // "few simple attachments" relationship the UI treats as one unit, not an
  // open-ended one.
  @Column({
    name: 'photo_storage_keys',
    type: 'text',
    array: true,
    nullable: true,
  })
  photoStorageKeys: string[] | null;

  @Column({
    type: 'enum',
    enum: MissionStatus,
    enumName: 'mission_status_enum',
    default: MissionStatus.PENDING_MODERATION,
  })
  status: MissionStatus;

  // Coarse weekday + hour preference, not a real calendar date — see
  // MissionTimingPreference. scheduledDayOfWeek/scheduledHour are only ever
  // non-null together, and only when this is SCHEDULED.
  @Column({
    name: 'timing_preference',
    type: 'enum',
    enum: MissionTimingPreference,
    enumName: 'mission_timing_preference_enum',
    default: MissionTimingPreference.UNSPECIFIED,
  })
  timingPreference: MissionTimingPreference;

  // 1 (Monday) .. 7 (Sunday) — Dart's DateTime.weekday convention, so the
  // mobile side never has to translate.
  @Column({ name: 'scheduled_day_of_week', type: 'smallint', nullable: true })
  scheduledDayOfWeek: number | null;

  @Column({ name: 'scheduled_hour', type: 'smallint', nullable: true })
  scheduledHour: number | null;

  // Poster's proposed opening figure for the job — a starting point for
  // negotiation, not a binding price. No currency column: the app has no
  // single launch currency (CFA countries vs Lebanon in USD — see
  // SubscriptionTier.priceLabel), so this is shown as a plain number and the
  // two sides settle currency the same way they already settle everything
  // else about the job, by talking directly.
  @Column({
    name: 'starting_price',
    type: 'numeric',
    precision: 12,
    scale: 2,
    nullable: true,
  })
  startingPrice: string | null;

  // Set by AdminService.rejectMission — shown back to the poster alongside
  // the "rejected, please edit and resubmit" state.
  @Column({ name: 'rejection_reason', type: 'text', nullable: true })
  rejectionReason: string | null;

  // Set once the poster picks a candidate (MissionsService.selectApplicant).
  // FK constraint added in a follow-up migration, after mission_applications
  // exists (the two tables mutually reference each other).
  @Column({ name: 'selected_application_id', type: 'uuid', nullable: true })
  selectedApplicationId: string | null;

  @Column({ name: 'published_at', type: 'timestamptz', nullable: true })
  publishedAt: Date | null;

  @Column({ name: 'selected_at', type: 'timestamptz', nullable: true })
  selectedAt: Date | null;

  @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
  completedAt: Date | null;

  @Column({ name: 'archived_at', type: 'timestamptz', nullable: true })
  archivedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
