import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsOptional,
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
}
