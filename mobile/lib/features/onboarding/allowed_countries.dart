import 'package:intl_phone_field/countries.dart' show Country, countries;
import 'package:intl_phone_field/phone_number.dart';

// Only markets currently launched (see registration_screen.dart's
// IntlPhoneField and OnboardingState.isCountryLaunched). Order fixes the
// picker's display order: Côte d'Ivoire, the 2026-11 African wave (artisan
// side open, clients on the waitlist — see AddAfricanCountries1791300000000
// on the backend), Liban, then Russie. Must match CreateDistrictDto's
// LAUNCHED_COUNTRY_CODES (plus RU, which has no districts yet). Shared
// between the screen and OnboardingController (which needs it to match a
// Phone Number Hint API result against a dial code — see
// core/auth/phone_hint_service.dart).
final List<Country> allowedCountries = [
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
  'RU',
].map(_withLocalLengths).toList();

// intl_phone_field 3.2.0's lengths are out of date for two of these markets,
// and its number field doesn't accept the leading trunk "0" most people type
// in Ghana, Nigeria and RD Congo (so the [min, max] below allow it, and
// toE164 strips it). Côte d'Ivoire, Bénin and Congo-Brazzaville have no trunk
// prefix: their leading 0 is part of the number.
const _localLengths = {
  'BJ': (10, 10), // 10 digits ("01…") since the 2024 renumbering
  'CG': (9, 9), // "06 123 4567"
  'GH': (9, 10),
  'NG': (10, 11),
  'CD': (9, 10),
};
const _trunkZeroCountries = {'GH', 'NG', 'CD'};

Country _withLocalLengths(String code) {
  final country = countries.firstWhere((c) => c.code == code);
  final lengths = _localLengths[code];
  if (lengths == null) return country;
  return Country(
    name: country.name,
    flag: country.flag,
    code: country.code,
    dialCode: country.dialCode,
    nameTranslations: country.nameTranslations,
    minLength: lengths.$1,
    maxLength: lengths.$2,
    regionCode: country.regionCode,
  );
}

// The number as the backend expects it (E.164), e.g. "024 412 3456" typed
// with Ghana selected → "+233244123456" rather than "+2330244123456".
String toE164(PhoneNumber phoneNumber) {
  final number = phoneNumber.number;
  if (_trunkZeroCountries.contains(phoneNumber.countryISOCode) &&
      number.startsWith('0')) {
    return '${phoneNumber.countryCode}${number.substring(1)}';
  }
  return phoneNumber.completeNumber;
}
