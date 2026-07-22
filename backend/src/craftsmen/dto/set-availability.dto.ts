import {
  IsBoolean,
  IsLatitude,
  IsLongitude,
  ValidateIf,
} from 'class-validator';

export class SetAvailabilityDto {
  @IsBoolean()
  available: boolean;

  // Only meaningful (and required) when going online — Redis presence needs
  // a starting point to geo-index. Going offline drops it regardless.
  @ValidateIf((dto: SetAvailabilityDto) => dto.available)
  @IsLatitude()
  latitude?: number;

  @ValidateIf((dto: SetAvailabilityDto) => dto.available)
  @IsLongitude()
  longitude?: number;
}
