// Every country Fix Pro accepts registrations from (District.countryCode),
// in admin display order. CI and LB are fully open; the 2026-11 African
// wave launched artisan side first (see AddAfricanCountries1791300000000).
// Kept in sync with the app's allowedCountries (minus RU, which has no
// districts yet) and the admin panel's adminCountries.
export const LAUNCHED_COUNTRY_CODES = [
  'CI',
  'SN',
  'CM',
  'BJ',
  'TG',
  'BF',
  'ML',
  'GN',
  'GH',
  'NG',
  'CG',
  'CD',
  'LB',
] as const;
