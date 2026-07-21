import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

// Shape is a guess, not Wave's real webhook contract — nobody has seen that
// yet (no Developers tab access on the business account). Replace this once
// real docs exist; PaymentsService only depends on `reference` and `status`.
export class WaveWebhookDto {
  @IsNotEmpty()
  @IsString()
  reference: string;

  @IsIn(['success', 'failed'])
  status: 'success' | 'failed';

  @IsOptional()
  @IsString()
  transactionId?: string;
}
