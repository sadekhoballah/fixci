import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity('site_visits')
export class SiteVisit {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'ip_address', type: 'varchar', length: 64 })
  ipAddress: string;

  // ISO 3166-1 alpha-2, resolved offline via geoip-lite — null for
  // private/local/unresolvable IPs (e.g. testing from the VPS itself).
  @Column({ name: 'country_code', type: 'varchar', length: 2, nullable: true })
  countryCode: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  path: string | null;

  @Index()
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
