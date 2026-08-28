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
import type { StoredIdDocAnalysis } from '../../uploads/id-document-check';

@Entity('client_profiles')
export class ClientProfile {
  @PrimaryColumn('uuid', { name: 'user_id' })
  userId: string;

  @OneToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({
    name: 'id_card_storage_key',
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  idCardStorageKey: string | null;

  @Column({ name: 'id_verified', type: 'boolean', default: false })
  idVerified: boolean;

  // Google Vision auto-check verdict from ID-photo upload time — advisory,
  // pre-scores the manual review queue, never gates anything. See
  // CraftsmanProfile.idAutoCheck and uploads/id-document-check.ts.
  @Column({ name: 'id_auto_check', type: 'jsonb', nullable: true })
  idAutoCheck: StoredIdDocAnalysis | null;

  // Set by AdminService.deactivateClient when an admin rejects the KYC
  // submission — shown back to the client alongside the "rejected, please
  // resubmit" state so they know what to fix.
  @Column({ name: 'id_rejection_reason', type: 'text', nullable: true })
  idRejectionReason: string | null;

  // Admin kill switch, mirroring CraftsmanProfile.isActive — set false by
  // AdminService.deactivateClient (the "reject" action on the review
  // screen). False only ever means an admin rejected this account; every
  // account starts true.
  @Column({ name: 'is_active', type: 'boolean', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
