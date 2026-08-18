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
