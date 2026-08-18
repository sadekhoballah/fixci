import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { ServiceCategory } from '../../database/enums/service-category.enum';

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
}
