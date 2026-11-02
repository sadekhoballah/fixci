import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_field/phone_number.dart';

import 'package:mobile/features/onboarding/allowed_countries.dart';

PhoneNumber _number(String iso, String dial, String number) =>
    PhoneNumber(countryISOCode: iso, countryCode: dial, number: number);

void main() {
  test('every launched country resolves, with corrected lengths', () {
    final byCode = {for (final c in allowedCountries) c.code: c};
    expect(byCode.keys, containsAll(['CI', 'SN', 'CM', 'NG', 'CD', 'LB']));
    expect(byCode['BJ']!.maxLength, 10);
    expect(byCode['CG']!.minLength, 9);
    expect(byCode['CI']!.maxLength, 10);
  });

  test('strips the trunk 0 only where it is not part of the number', () {
    expect(toE164(_number('GH', '+233', '0244123456')), '+233244123456');
    expect(toE164(_number('NG', '+234', '08031234567')), '+2348031234567');
    expect(toE164(_number('NG', '+234', '8031234567')), '+2348031234567');
    expect(toE164(_number('CI', '+225', '0707070707')), '+2250707070707');
    expect(toE164(_number('BJ', '+229', '0197123456')), '+2290197123456');
  });
}
