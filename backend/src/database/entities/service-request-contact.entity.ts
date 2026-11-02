import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { User } from './user.entity';
import { ServiceRequest } from './service-request.entity';

export type ContactChannel = 'whatsapp' | 'call';

// One row per (request, craftsman, channel) a client reached out through
// from the post-window "contact directly" list (see MatchingService.
// findFallbackCraftsmen) — the only trace the app keeps of a job that was
// arranged over WhatsApp / a phone call rather than accepted in-app. Feeds
// the admin "Ops live détaillée" view. Repeated taps on the same button
// collapse onto the existing row (unique constraint below).
@Entity('service_request_contacts')
@Unique('UQ_service_request_contacts_request_craftsman_channel', [
  'serviceRequestId',
  'craftsmanId',
  'channel',
])
export class ServiceRequestContact {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'service_request_id', type: 'uuid' })
  serviceRequestId: string;

  @ManyToOne(() => ServiceRequest, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'service_request_id' })
  serviceRequest: ServiceRequest;

  @Column({ name: 'client_id', type: 'uuid' })
  clientId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'client_id' })
  client: User;

  @Column({ name: 'craftsman_id', type: 'uuid' })
  craftsmanId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'craftsman_id' })
  craftsman: User;

  @Column({ type: 'varchar', length: 16 })
  channel: ContactChannel;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
