import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/countries.dart' show Country;

// Android's Phone Number Hint API (com.google.android.gms.auth.api.identity,
// part of Google Play services — NOT Firebase Auth) — see MainActivity.kt
// for the platform-channel side. Deliberately hand-rolled instead of a
// pub.dev plugin: the whole API surface is one call, and owning it directly
// guarantees the one thing that actually matters here — this never
// requests READ_PHONE_STATE/READ_PHONE_NUMBERS, and structurally can't,
// since the channel only ever launches a system-owned picker and hands back
// whatever the user picked in it.
//
// There is no iOS equivalent (Apple never exposes the device's phone number
// to apps) — isSupported gates every call site so iOS/desktop/web just skip
// straight to manual entry, same as the "no numbers on this device" case
// below.
class PhoneHintService {
  static const _channel = MethodChannel('com.fixci.mobile/phone_hint');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  // Returns the raw string the device reported (may or may not be in E.164
  // format — see parsePhoneHint below), or null when there's nothing to
  // offer: no SIM, a carrier that never wrote a number to it (common in
  // Côte d'Ivoire — see AGENTS/founder notes), the user dismissed the
  // picker, or the device has no Play services at all. Android's API
  // doesn't distinguish "genuinely nothing available" from "user cancelled
  // a picker that had numbers" — both surface as an empty result here, and
  // the caller (OnboardingController) treats them identically: fall back to
  // manual entry.
  Future<String?> requestHint() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('requestHint');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

final phoneHintServiceProvider = Provider<PhoneHintService>(
  (ref) => PhoneHintService(),
);

class ParsedPhoneHint {
  const ParsedPhoneHint({
    required this.e164Number,
    required this.localNumber,
    required this.countryIsoCode,
  });

  // Full number in "+<dialCode><localNumber>" form — what gets sent to the
  // backend and what OnboardingState.phone stores.
  final String e164Number;
  // Just the part after the dial code — what IntlPhoneField's own
  // controller/text should show, since it renders the dial code separately
  // via its flag prefix.
  final String localNumber;
  final String countryIsoCode;
}

// Matches the hint API's result against one of the countries this app has
// actually launched in (see RegistrationScreen._allowedCountries), so the
// country selector can be locked to the right flag. A hint in full
// international format ("+2250700000001") is matched by dial-code prefix,
// longest first (so e.g. a 3-digit dial code isn't shadowed by a shorter
// one that happens to also prefix-match). A hint without a leading "+"
// (some OEMs/carriers write the SIM's number in national format) can't be
// attributed to a country by itself, so it's taken at face value as a
// local number in whichever country is already selected.
ParsedPhoneHint parsePhoneHint(
  String raw, {
  required List<Country> allowedCountries,
  required String currentCountryIsoCode,
}) {
  final digitsAndPlus = raw.replaceAll(RegExp(r'[^0-9+]'), '');

  if (digitsAndPlus.startsWith('+')) {
    final digits = digitsAndPlus.substring(1);
    final byDialCodeLengthDesc = [...allowedCountries]
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    for (final country in byDialCodeLengthDesc) {
      if (digits.startsWith(country.dialCode)) {
        return ParsedPhoneHint(
          e164Number: '+$digits',
          localNumber: digits.substring(country.dialCode.length),
          countryIsoCode: country.code,
        );
      }
    }
  }

  final fallbackCountry = allowedCountries.firstWhere(
    (c) => c.code == currentCountryIsoCode,
    orElse: () => allowedCountries.first,
  );
  final localDigitsOnly = digitsAndPlus.replaceAll('+', '');
  return ParsedPhoneHint(
    e164Number: '+${fallbackCountry.dialCode}$localDigitsOnly',
    localNumber: localDigitsOnly,
    countryIsoCode: fallbackCountry.code,
  );
}
