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
import { Mission } from './mission.entity';
import { MissionApplicationStatus } from '../enums/mission-application-status.enum';

// A "Candidater" tap on a Mission. applicantLocation is a SNAPSHOT captured
// fresh (via the mobile app's getCurrentPosition()) at the moment of
// applying — not a live lookup against CraftsmanProfile.location, because
// ClientProfile has no location field at all and missions are symmetric
// (a client can apply too). This keeps distance math working uniformly for
// both roles without depending on which profile table the applicant has.
@Entity('mission_applications')
export class MissionApplication {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'mission_id', type: 'uuid' })
  missionId: string;

  @ManyToOne(() => Mission, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'mission_id' })
  mission: Mission;

  @Column({ name: 'applicant_id', type: 'uuid' })
  applicantId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'applicant_id' })
  applicant: User;

  @Column({
    type: 'enum',
    enum: MissionApplicationStatus,
    enumName: 'mission_application_status_enum',
    default: MissionApplicationStatus.PENDING,
  })
  status: MissionApplicationStatus;

  // See CraftsmanProfile.location for the raw-EWKB round-trip caveat.
  @Column({
    name: 'applicant_location',
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  applicantLocation: string;

  @Column({ type: 'text', nullable: true })
  message: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
