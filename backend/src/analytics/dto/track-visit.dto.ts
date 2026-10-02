import { IsOptional, IsString, MaxLength } from 'class-validator';

export class TrackVisitDto {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  path?: string;
}
