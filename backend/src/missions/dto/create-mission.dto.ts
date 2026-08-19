import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
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

export class CreateMissionDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(150)
  title: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(2000)
  description: string;

  // Browse/filter tag only — never fed into the real-time matching engine.
  // Optional: a mission doesn't have to fit a fixed trade.
  @IsOptional()
  @IsEnum(ServiceCategory)
  category?: ServiceCategory;

  @IsNotEmpty()
  @IsString()
  @MaxLength(500)
  locationAddress: string;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;

  // Storage keys returned by POST /uploads/mission-photo, uploaded
  // individually beforehand — see UploadsController.
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(3)
  @IsString({ each: true })
  @MaxLength(255, { each: true })
  photoStorageKeys?: string[];

  // Defaults to UNSPECIFIED server-side when omitted (see
  // MissionsService.createMission) — mirrors the entity's own column
  // default, so an old client that never sends this field still works.
  @IsOptional()
  @IsEnum(MissionTimingPreference)
  timingPreference?: MissionTimingPreference;

  // Required together, and only meaningful, when timingPreference is
  // SCHEDULED — enforced here rather than by a DB constraint, same trust
  // boundary as latitude/longitude above.
  @ValidateIf(
    (dto: CreateMissionDto) =>
      dto.timingPreference === MissionTimingPreference.SCHEDULED,
  )
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(7)
  scheduledDayOfWeek?: number;

  @ValidateIf(
    (dto: CreateMissionDto) =>
      dto.timingPreference === MissionTimingPreference.SCHEDULED,
  )
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(23)
  scheduledHour?: number;

  // Poster's opening figure, currency-agnostic — see Mission.startingPrice.
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  startingPrice?: number;
}
