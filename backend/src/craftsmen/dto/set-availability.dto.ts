import {
  IsBoolean,
  IsLatitude,
  IsLongitude,
  Matches,
  ValidateIf,
} from 'class-validator';

export class SetAvailabilityDto {
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: 'phone must be in E.164 format, e.g. +2250700000001',
  })
  phone: string;

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
