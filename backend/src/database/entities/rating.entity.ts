import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';
import { ServiceRequest } from './service-request.entity';

@Entity('ratings')
export class Rating {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'service_request_id', type: 'uuid', unique: true })
  serviceRequestId: string;

  @OneToOne(() => ServiceRequest, { onDelete: 'CASCADE' })
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

  @Column({ type: 'smallint' })
  stars: number;

  @Column({ type: 'text', nullable: true })
  comment: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
