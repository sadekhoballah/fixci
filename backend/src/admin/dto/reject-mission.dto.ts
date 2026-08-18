import { IsOptional, IsString, MaxLength } from 'class-validator';

export class RejectMissionDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
