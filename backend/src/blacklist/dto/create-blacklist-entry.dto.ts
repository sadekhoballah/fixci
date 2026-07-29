import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class CreateBlacklistEntryDto {
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: 'phone must be in E.164 format, e.g. +2250700000001',
  })
  phone: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
