import { IsNotEmpty, IsString } from 'class-validator';

export class GetPaymentStatusDto {
  @IsString()
  @IsNotEmpty()
  reference: string;
}
