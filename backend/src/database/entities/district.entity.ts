import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('districts')
export class District {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 120, unique: true })
  name: string;

  // ISO 3166-1 alpha-2. Matches registration_screen.dart's phone country
  // picker (_allowedCountries) — the client filters this list by whichever
  // country the caller picked for their phone number, so a district here
  // with no matching launched market just never shows up client-side.
  @Column({ name: 'country_code', type: 'varchar', length: 2, default: 'CI' })
  countryCode: string;

  // Gates whether a craftsman registered in this district can ever go
  // online (see PresenceService.setOnline) — registration itself is never
  // blocked, so this is what actually makes a closed district a waitlist
  // rather than a rejection.
  @Column({
    name: 'is_artisan_registration_active',
    type: 'boolean',
    default: true,
  })
  isArtisanRegistrationActive: boolean;

  // Gates whether a client in this district can create a service request
  // (see MatchingController.createRequest) — same waitlist rationale.
  @Column({ name: 'is_client_ordering_active', type: 'boolean', default: true })
  isClientOrderingActive: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
