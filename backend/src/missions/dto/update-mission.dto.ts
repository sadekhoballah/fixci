import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';
import { ServiceCategory } from '../../database/enums/service-category.enum';
import { MissionTimingPreference } from '../../database/enums/mission-timing-preference.enum';

// Used only for the "edit and resubmit after rejection" flow
// (MissionsService.updateMission) — every field optional, unlike
// CreateMissionDto, since the poster is patching an existing row.
export class UpdateMissionDto {
  @IsOptional()
  @IsString()
  @MaxLength(150)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsEnum(ServiceCategory)
  category?: ServiceCategory;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  locationAddress?: string;

  // latitude/longitude travel together — if one is sent, both must be, so
  // the service can tell "keep existing location" apart from "move it".
  @IsOptional()
  @IsLatitude()
  latitude?: number;

  @IsOptional()
  @IsLongitude()
  longitude?: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(3)
  @IsString({ each: true })
  @MaxLength(255, { each: true })
  photoStorageKeys?: string[];

  @IsOptional()
  @IsEnum(MissionTimingPreference)
  timingPreference?: MissionTimingPreference;

  // Required together, and only meaningful, when timingPreference is being
  // set to SCHEDULED in this same request — mirrors CreateMissionDto.
  @ValidateIf(
    (dto: UpdateMissionDto) =>
      dto.timingPreference === MissionTimingPreference.SCHEDULED,
  )
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(7)
  scheduledDayOfWeek?: number;

  @ValidateIf(
    (dto: UpdateMissionDto) =>
      dto.timingPreference === MissionTimingPreference.SCHEDULED,
  )
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(23)
  scheduledHour?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  startingPrice?: number;
}
