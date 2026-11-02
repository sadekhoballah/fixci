import { IsIn, IsUUID } from 'class-validator';
import type { ContactChannel } from '../../database/entities/service-request-contact.entity';

export class RecordContactDto {
  @IsUUID()
  craftsmanId: string;

  @IsIn(['whatsapp', 'call'])
  channel: ContactChannel;
}
