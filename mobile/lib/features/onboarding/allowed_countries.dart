import 'package:intl_phone_field/countries.dart' show Country, countries;

// Only markets currently launched (see registration_screen.dart's
// IntlPhoneField and OnboardingState.isCountryLaunched). Order fixes the
// picker's display order (Côte d'Ivoire, then Liban, then Russie). Shared
// between the screen and OnboardingController (which needs it to match a
// Phone Number Hint API result against a dial code — see
// core/auth/phone_hint_service.dart).
final List<Country> allowedCountries = ['CI', 'LB', 'RU']
    .map((code) => countries.firstWhere((c) => c.code == code))
    .toList();
