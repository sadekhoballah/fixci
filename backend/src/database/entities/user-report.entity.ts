import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';
import { ReportReason } from '../enums/report-reason.enum';
import { ReportStatus } from '../enums/report-status.enum';

// A user-to-user safety report — filed from wherever the other party's
// contact info is shown (a mission's poster/applicant, an active job/
// request's counterpart), reviewed from the admin Signalements queue. Never
// auto-blocks on its own — see UserBlock, a same-shaped but separate table
// the mobile client writes to independently (report form's "also block"
// checkbox fires both calls, not one combined one).
@Entity('user_reports')
export class UserReport {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'reporter_id', type: 'uuid' })
  reporterId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporter_id' })
  reporter: User;

  @Column({ name: 'reported_user_id', type: 'uuid' })
  reportedUserId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reported_user_id' })
  reportedUser: User;

  @Column({
    type: 'enum',
    enum: ReportReason,
    enumName: 'report_reason_enum',
  })
  reason: ReportReason;

  @Column({ type: 'text', nullable: true })
  message: string | null;

  // Which mission/service-request this happened on, if any — purely for the
  // admin's own context when reviewing (e.g. a direct link into that
  // mission), not enforced with a FK: the two possible targets (missions,
  // service_requests) don't share one table, and either row may itself be
  // long gone by review time without that invalidating the report itself.
  @Column({ name: 'context_type', type: 'varchar', length: 30, nullable: true })
  contextType: 'mission' | 'service_request' | null;

  @Column({ name: 'context_id', type: 'uuid', nullable: true })
  contextId: string | null;

  @Column({
    type: 'enum',
    enum: ReportStatus,
    enumName: 'report_status_enum',
    default: ReportStatus.PENDING,
  })
  status: ReportStatus;

  // Set by AdminService.resolveReport — the admin's own note on why this
  // was dismissed/resolved a given way, never shown back to either party.
  @Column({ name: 'admin_note', type: 'text', nullable: true })
  adminNote: string | null;

  @Column({ name: 'resolved_at', type: 'timestamptz', nullable: true })
  resolvedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
