import {
  IsBoolean,
  IsEnum,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { UserRole } from '../../database/enums/user-role.enum';
import { ServiceCategory } from '../../database/enums/service-category.enum';
import { LAUNCHED_COUNTRY_CODES } from '../../districts/launched-countries';

export class SendBroadcastDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  title: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  body: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  // Only meaningful alongside role: 'craftsman' — enforced in
  // BroadcastService.send, not here, since it's a cross-field rule.
  @IsOptional()
  @IsEnum(ServiceCategory)
  serviceCategory?: ServiceCategory;

  // Every district of one country, e.g. all craftsmen in Sénégal.
  @IsOptional()
  @IsIn(LAUNCHED_COUNTRY_CODES)
  countryCode?: string;

  @IsOptional()
  @IsUUID()
  districtId?: string;

  @IsOptional()
  @IsBoolean()
  waitlistOnly?: boolean;
}
