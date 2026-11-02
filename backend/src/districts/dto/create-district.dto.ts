import { IsIn, IsNotEmpty, IsString, MaxLength } from 'class-validator';

// Restricted to launched markets on purpose — Russie is in the phone
// picker (registration_screen.dart's _allowedCountries) but has no
// districts at all yet (registration is blocked client-side with a
// "coming soon" notice instead), so it's deliberately not a valid choice
// here until that actually launches.
// The 2026-11 African wave (SN … GN) launches artisan-side first: their
// cities are seeded with client ordering closed until each has enough
// verified craftsmen (see AddAfricanCountries1791300000000).
const LAUNCHED_COUNTRY_CODES = [
  'CI',
  'LB',
  'SN',
  'CM',
  'BJ',
  'TG',
  'GH',
  'NG',
  'CG',
  'CD',
  'BF',
  'ML',
  'GN',
];

export class CreateDistrictDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(120)
  name: string;

  @IsIn(LAUNCHED_COUNTRY_CODES)
  countryCode: string;
}
