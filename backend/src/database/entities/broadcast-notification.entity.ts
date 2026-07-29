import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { UserRole } from '../enums/user-role.enum';
import { ServiceCategory } from '../enums/service-category.enum';
import { District } from './district.entity';

// A log of past sends, not a queue — the push itself is fire-and-forget at
// send time (see BroadcastService.send), this row just records what was
// sent, to whom, and how many actually got it.
@Entity('broadcast_notifications')
export class BroadcastNotification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 120 })
  title: string;

  @Column({ type: 'text' })
  body: string;

  @Column({
    name: 'target_role',
    type: 'enum',
    enum: UserRole,
    enumName: 'user_role_enum',
    nullable: true,
  })
  targetRole: UserRole | null;

  @Column({
    name: 'target_service_category',
    type: 'enum',
    enum: ServiceCategory,
    enumName: 'service_category_enum',
    nullable: true,
  })
  targetServiceCategory: ServiceCategory | null;

  @Column({ name: 'target_district_id', type: 'uuid', nullable: true })
  targetDistrictId: string | null;

  @ManyToOne(() => District, { nullable: true })
  @JoinColumn({ name: 'target_district_id' })
  targetDistrict: District | null;

  @Column({ name: 'waitlist_only', type: 'boolean', default: false })
  waitlistOnly: boolean;

  @Column({ name: 'recipient_count', type: 'integer' })
  recipientCount: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
