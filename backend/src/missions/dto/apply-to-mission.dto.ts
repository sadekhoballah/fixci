import {
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class ApplyToMissionDto {
  // Captured fresh by the app at the moment "Candidater" is tapped — see
  // MissionApplication.applicantLocation for why this is a snapshot rather
  // than a lookup against a persisted profile location.
  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;
}
