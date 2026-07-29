import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

// Rejects registration outright — unlike District (a waitlist: registration
// always succeeds, only going-online/ordering is gated), a blacklisted
// phone never gets an account at all. See UsersService.register.
@Entity('blacklisted_phones')
export class BlacklistedPhone {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 20, unique: true })
  phone: string;

  @Column({ type: 'text', nullable: true })
  reason: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
