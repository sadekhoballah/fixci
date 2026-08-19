import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsUUID,
  Max,
  Min,
  ValidateIf,
} from 'class-validator';
import { ServiceCategory } from '../../database/enums/service-category.enum';

export class BrowseMissionsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;

  @IsOptional()
  @IsEnum(ServiceCategory)
  category?: ServiceCategory;

  // Both optional, but paired: if either is sent, both must be — mirrors
  // CreateServiceRequestDto's destinationAddress @ValidateIf shape. When
  // omitted entirely, the board is sorted by createdAt instead of distance
  // and distanceMeters comes back null on every item.
  @ValidateIf((dto: BrowseMissionsQueryDto) => dto.longitude !== undefined)
  @Type(() => Number)
  @IsLatitude()
  latitude?: number;

  @ValidateIf((dto: BrowseMissionsQueryDto) => dto.latitude !== undefined)
  @Type(() => Number)
  @IsLongitude()
  longitude?: number;

  // Explicit district to browse — any district, not just the caller's own
  // (founder's call: a craftsman/client can shop missions anywhere). Omitted
  // entirely, MissionsService.browseMissions falls back to the caller's own
  // district so the board is pre-filtered the instant the page opens.
  @IsOptional()
  @IsUUID()
  districtId?: string;

  // Explicit opt-out of the own-district default above — lets the mobile
  // client offer a "Tous les districts" choice in the same picker as
  // districtId, distinguishable from "param omitted" (which means
  // "default to my district", not "no filter at all").
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  allDistricts?: boolean;

  // Hard radius cap in km, only applied when latitude/longitude are also
  // supplied — mobile sends this (5) on the default "near me" load and
  // omits it once the caller explicitly picks a different district (see
  // MissionsBoardController), since capping by the caller's own distance
  // makes no sense once they're deliberately browsing somewhere else.
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  maxDistanceKm?: number;
}
