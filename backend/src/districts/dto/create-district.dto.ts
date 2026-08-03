import { IsIn, IsNotEmpty, IsString, MaxLength } from 'class-validator';

// Restricted to launched markets on purpose — Russie is in the phone
// picker (registration_screen.dart's _allowedCountries) but has no
// districts at all yet (registration is blocked client-side with a
// "coming soon" notice instead), so it's deliberately not a valid choice
// here until that actually launches.
const LAUNCHED_COUNTRY_CODES = ['CI', 'LB'];

export class CreateDistrictDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(120)
  name: string;

  @IsIn(LAUNCHED_COUNTRY_CODES)
  countryCode: string;
}
