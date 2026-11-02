import { IsIn, IsOptional } from 'class-validator';
import { LAUNCHED_COUNTRY_CODES } from '../launched-countries';

// Optional ?country=SN on admin listings — narrows to users whose district
// is in that country (requests and missions by their client / poster).
export class CountryFilterDto {
  @IsOptional()
  @IsIn(LAUNCHED_COUNTRY_CODES)
  country?: string;
}
