import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

// Shape is a guess, not any specific provider's real webhook contract —
// nobody has seen either Wave's or Whish's yet (no Developers/API access on
// either business account). Shared by both /payments/wave/webhook and
// /payments/whish/webhook since PaymentsService only depends on `reference`
// and `status`, which are provider-agnostic — replace with per-provider
// shapes only if a real contract turns out to actually need it.
export class PaymentWebhookDto {
  @IsNotEmpty()
  @IsString()
  reference: string;

  @IsIn(['success', 'failed'])
  status: 'success' | 'failed';

  @IsOptional()
  @IsString()
  transactionId?: string;
}
