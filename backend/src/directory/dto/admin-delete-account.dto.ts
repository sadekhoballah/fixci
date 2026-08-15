import { IsOptional, IsString, MaxLength } from 'class-validator';

export class AdminDeleteAccountDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
