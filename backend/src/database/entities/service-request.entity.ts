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
import { ServiceRequestStatus } from '../enums/service-request-status.enum';

@Entity('service_requests')
export class ServiceRequest {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'client_id', type: 'uuid' })
  clientId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'client_id' })
  client: User;

  @Column({ name: 'craftsman_id', type: 'uuid', nullable: true })
  craftsmanId: string | null;

  @ManyToOne(() => User, { onDelete: 'RESTRICT', nullable: true })
  @JoinColumn({ name: 'craftsman_id' })
  craftsman: User | null;

  @Column({
    name: 'service_category',
    type: 'enum',
    enum: ServiceCategory,
    enumName: 'service_category_enum',
  })
  serviceCategory: ServiceCategory;

  @Column({
    type: 'enum',
    enum: ServiceRequestStatus,
    enumName: 'service_request_status_enum',
    default: ServiceRequestStatus.PENDING,
  })
  status: ServiceRequestStatus;

  // See CraftsmanProfile.location for the raw-EWKB round-trip caveat.
  @Column({
    name: 'client_location',
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  clientLocation: string;

  @Column({ name: 'search_radius_meters', type: 'integer', default: 5000 })
  searchRadiusMeters: number;

  @Column({ name: 'assigned_at', type: 'timestamptz', nullable: true })
  assignedAt: Date | null;

  @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
  completedAt: Date | null;

  @Column({ name: 'cancelled_at', type: 'timestamptz', nullable: true })
  cancelledAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
