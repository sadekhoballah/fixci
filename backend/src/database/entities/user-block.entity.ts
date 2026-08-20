import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';

// A one-directional block record, but always enforced bidirectionally by
// every caller (SafetyService.getBlockedCounterpartIds checks both
// (blockerId=me) and (blockedUserId=me)) — if A blocks B, B is hidden from
// A *and* A from B. A one-way block where B keeps trying and it silently
// fails would read as a bug, not a boundary. Self-service and reversible:
// see SafetyService.unblockUser, surfaced as "Utilisateurs bloqués" in the
// Compte screen.
@Entity('user_blocks')
export class UserBlock {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'blocker_id', type: 'uuid' })
  blockerId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'blocker_id' })
  blocker: User;

  @Column({ name: 'blocked_user_id', type: 'uuid' })
  blockedUserId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'blocked_user_id' })
  blockedUser: User;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
