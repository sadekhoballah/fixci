import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserRole } from '../enums/user-role.enum';
import { District } from './district.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 20, unique: true })
  phone: string;

  @Column({ name: 'full_name', type: 'varchar', length: 120, nullable: true })
  fullName: string | null;

  @Column({ type: 'enum', enum: UserRole, enumName: 'user_role_enum' })
  role: UserRole;

  // Picked manually at registration (no geofencing) — shared by both roles
  // since a User row exists regardless of client/craftsman, and gates
  // whether this account can actually operate (see District entity) rather
  // than whether it can register at all.
  @Column({ name: 'district_id', type: 'uuid' })
  districtId: string;

  @ManyToOne(() => District)
  @JoinColumn({ name: 'district_id' })
  district: District;

  @Column({ name: 'phone_verified', type: 'boolean', default: false })
  phoneVerified: boolean;

  // The device this user last opened the app on. Single column, not a
  // table: one active FCM registration per account is enough for an MVP
  // where nobody is expected to be logged in on two devices at once — a
  // fresh login just overwrites the old token, which is also what you want
  // when someone reinstalls or switches phones.
  @Column({ name: 'fcm_token', type: 'varchar', length: 255, nullable: true })
  fcmToken: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
