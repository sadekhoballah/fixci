import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateDistrictTogglesDto {
  @IsOptional()
  @IsBoolean()
  isArtisanRegistrationActive?: boolean;

  @IsOptional()
  @IsBoolean()
  isClientOrderingActive?: boolean;
}
