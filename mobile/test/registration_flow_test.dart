import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app.dart';
import 'package:mobile/core/auth/phone_hint_service.dart';
import 'package:mobile/core/auth/session_storage.dart';
import 'package:mobile/core/auth/token_storage.dart';
import 'package:mobile/core/localization/locale_storage.dart';
import 'package:mobile/core/media/id_card_picker.dart';
import 'package:mobile/core/models/subscription_tier.dart';
import 'package:mobile/core/models/user_role.dart';
import 'package:mobile/core/models/district.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/onboarding/onboarding_controller.dart';
import 'package:mobile/features/onboarding/otp_controller.dart';
import 'package:mobile/l10n/app_localizations.dart';

const _fakeDistrict = District(
  id: 'fake-district-id',
  name: 'Cocody',
  countryCode: 'CI',
  isArtisanRegistrationActive: true,
  isClientOrderingActive: true,
);

const _correctOtpCode = '123456';

// A real 400x300 PNG — plausible ID-card-ish dimensions, passes validation
// (mirrors the constant in widget_test.dart).
const _plausibleIdCardPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAZAAAAEsAQMAAADXeXeBAAAAIGNIUk0AAHomAACAhAAA'
    '+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGUExURYfO6/////E3Kz4AAAABYkt'
    'HRAH/Ai3eAAAAB3RJTUUH6gcSCyoLx9crAQAAACZJREFUaN7twTEBAAAAwqD1T20JT6'
    'AAAAAAAAAAAAAAAAAAAICnATvEAAEnf54JAAAAAElFTkSuQmCC';

// Avoids the real FlutterSecureStorage-backed TokenStorage's platform
// channel calls, same rationale as _FakeSessionStorage below.
class _FakeTokenStorage implements TokenStorage {
  String? _accessToken;
  String? _refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<String?> loadAccessToken() async => _accessToken;

  @override
  Future<String?> loadRefreshToken() async => _refreshToken;

  @override
  Future<bool> hasSession() async => _refreshToken != null;

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}

// A phone number POST /auth/otp/check (below) reports as already belonging
// to an account, to exercise the "existing account" branch.
// _alreadyRegisteredLocalNumber is what a test types into the field (see
// fillAndSubmitRegistrationForm); _alreadyRegisteredPhone is the resulting
// E.164 form (+225 dial code) the fake backend matches against.
const _alreadyRegisteredLocalNumber = '0700000099';
const _alreadyRegisteredPhone = '+225$_alreadyRegisteredLocalNumber';

// Fakes only the true I/O boundary (mirrors _FakeApiClient in
// widget_test.dart) — everything above it (OnboardingController, OtpController,
// the screens) runs for real.
class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.failRegister = false})
    : super(
        l10n: lookupAppLocalizations(const Locale('fr')),
        tokenStorage: _FakeTokenStorage(),
      );

  final bool failRegister;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path == '/districts') {
      return {
        'items': [
          {
            'id': 'fake-district-id',
            'name': 'Cocody',
            'countryCode': 'CI',
            'isArtisanRegistrationActive': true,
            'isClientOrderingActive': true,
          },
        ],
      };
    }
    throw UnimplementedError('Unexpected path in fake client: $path');
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path == '/auth/otp/start') {
      return {'status': 'sent', 'channel': body['channel'] ?? 'whatsapp'};
    }
    if (path == '/auth/otp/check') {
      if (body['code'] != _correctOtpCode) {
        throw ApiException('Incorrect code', statusCode: 401);
      }
      if (body['phone'] == _alreadyRegisteredPhone) {
        return {
          'status': 'existing',
          'accessToken': 'fake-existing-access-token',
          'refreshToken': 'fake-existing-refresh-token',
          'user': {
            'id': 'fake-user-id',
            'phone': body['phone'],
            'fullName': 'Existing Client',
            'role': 'client',
            'subscriptionTier': null,
          },
        };
      }
      return {'status': 'new', 'registrationToken': 'fake-registration-token'};
    }
    if (path == '/users/register') {
      if (failRegister) {
        throw ApiException('Invalid phone number.');
      }
      return {
        'id': 'fake-user-id',
        'phone': body['phone'],
        'fullName': body['fullName'],
        'role': body['role'],
        'accessToken': 'fake-access-token',
        'refreshToken': 'fake-refresh-token',
      };
    }
    throw UnimplementedError('Unexpected path in fake client: $path');
  }

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path,
    String fieldName,
    List<int> bytes,
    String filename, {
    String? contentTypeHeader,
  }) async {
    if (path == '/uploads/id-card') {
      return {'storageKey': 'id-cards/fake.png'};
    }
    throw UnimplementedError('Unexpected path in fake client: $path');
  }
}

class _FakeIdCardPicker implements IdCardPicker {
  @override
  Future<PickedImage?> pickFromGallery() async => PickedImage(
    bytes: base64Decode(_plausibleIdCardPngBase64),
    filename: 'id.png',
    mimeType: 'image/png',
  );

  @override
  Future<PickedImage?> pickFromCamera() => pickFromGallery();
}

// A no-op stand-in for the real shared_preferences-backed SessionStorage —
// avoids touching the plugin's method channel, which isn't mocked in
// `flutter test`.
class _FakeSessionStorage implements SessionStorage {
  UserRole? _role;
  SubscriptionTier? _tier;
  String? _phone;

  @override
  Future<void> saveRole(UserRole role) async => _role = role;

  @override
  Future<UserRole?> loadRole() async => _role;

  @override
  Future<void> saveTier(SubscriptionTier tier) async => _tier = tier;

  @override
  Future<SubscriptionTier?> loadTier() async => _tier;

  @override
  Future<void> savePhone(String phone) async => _phone = phone;

  @override
  Future<String?> loadPhone() async => _phone;

  @override
  Future<void> clearSession() async {
    _role = null;
    _tier = null;
    _phone = null;
  }
}

// Avoids the real LocaleStorage's SharedPreferences.getInstance() call,
// which needs a mocked platform channel this suite doesn't set up — same
// rationale as _FakeSessionStorage above. Every test here relies on the
// app's default French copy, so "never had a saved locale" (null) is
// exactly the behavior these tests need.
class _FakeLocaleStorage implements LocaleStorage {
  @override
  Future<String?> loadLocaleCode() async => null;

  @override
  Future<void> saveLocaleCode(String code) async {}
}

// Never reports itself as supported unless a test opts in — widget tests
// run on the host platform (never "really" Android), so the real
// PhoneHintService.isSupported would always be false anyway; being
// explicit here documents that the manual-entry tests are exercising the
// same path a real iOS device or a real Android device with no SIM data
// would take, not an accident of the test host's OS.
class _FakePhoneHintService implements PhoneHintService {
  _FakePhoneHintService({this.isSupported = false, this.hint});

  @override
  final bool isSupported;
  final String? hint;

  @override
  Future<String?> requestHint() async => isSupported ? hint : null;
}

void main() {
  Widget buildApp({
    _FakeApiClient? apiClient,
    TokenStorage? tokenStorage,
    PhoneHintService? phoneHintService,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient ?? _FakeApiClient()),
        idCardPickerProvider.overrideWithValue(_FakeIdCardPicker()),
        sessionStorageProvider.overrideWithValue(_FakeSessionStorage()),
        tokenStorageProvider.overrideWithValue(
          tokenStorage ?? _FakeTokenStorage(),
        ),
        localeStorageProvider.overrideWithValue(_FakeLocaleStorage()),
        phoneHintServiceProvider.overrideWithValue(
          phoneHintService ?? _FakePhoneHintService(),
        ),
      ],
      child: const FixCiApp(),
    );
  }

  Future<void> attachIdCard(WidgetTester tester) async {
    await tester.ensureVisible(find.text("Ajouter votre pièce d'identité"));
    await tester.tap(find.text("Ajouter votre pièce d'identité"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir depuis la galerie'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  // Drives the OTP screen the same way every platform does — type the code,
  // tap Vérifier.
  Future<void> enterOtpCode(WidgetTester tester, {String code = _correctOtpCode}) async {
    expect(find.text('Vérification du numéro'), findsOneWidget);
    await tester.enterText(find.byType(TextField), code);
    await tester.pump();
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
  }

  // localNumber is what a real user types: just the national digits, since
  // the "+225" dial code is already shown separately via the field's flag
  // prefix (typing a full "+225..." string into the underlying TextField
  // would double up the dial code in PhoneNumber.completeNumber). Leaves the
  // flow sitting on the OTP verification screen.
  Future<void> fillAndSubmitRegistrationForm(
    WidgetTester tester, {
    required String localNumber,
    _FakeApiClient? apiClient,
    PhoneHintService? phoneHintService,
  }) async {
    await tester.pumpWidget(
      buildApp(apiClient: apiClient, phoneHintService: phoneHintService),
    );
    await tester.pumpAndSettle(const Duration(seconds: 4));

    await tester.tap(find.text('Client'));
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Prénom (comme sur votre pièce d\'identité)'),
      'Aya',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nom de famille (comme sur votre pièce d\'identité)'),
      'Kone',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Numéro de téléphone'),
      localNumber,
    );
    await tester.pump();

    // districtsProvider resolves asynchronously (GET /districts) — wait for
    // it before the dropdown has anything to select. District is mandatory
    // (OnboardingState.isRegistrationComplete).
    await tester.pumpAndSettle();
    await tester.tap(find.text('Votre zone / commune'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cocody').last);
    await tester.pumpAndSettle();

    await attachIdCard(tester);

    await tester.ensureVisible(find.text("S'inscrire"));
    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a phone number registers after passing OTP verification',
    (tester) async {
      await fillAndSubmitRegistrationForm(tester, localNumber: '0700000001');

      await enterOtpCode(tester);

      expect(find.text('Bienvenue, Aya Kone !'), findsOneWidget);
    },
  );

  testWidgets(
    'a registration failure after OTP shows an inline error on the verification screen',
    (tester) async {
      await fillAndSubmitRegistrationForm(
        tester,
        localNumber: '0700000002',
        apiClient: _FakeApiClient(failRegister: true),
      );

      await enterOtpCode(tester);

      expect(find.text('Vérification du numéro'), findsOneWidget);
      expect(find.text('Invalid phone number.'), findsOneWidget);
      expect(find.text('Bienvenue, Aya Kone !'), findsNothing);
    },
  );

  testWidgets('a wrong OTP code shows an error and stays on the verification screen', (
    tester,
  ) async {
    await fillAndSubmitRegistrationForm(tester, localNumber: '0700000003');

    await enterOtpCode(tester, code: '999999');

    expect(find.text('Vérification du numéro'), findsOneWidget);
    expect(find.text('Code incorrect. Veuillez réessayer.'), findsOneWidget);
  });

  test(
    'requestPhoneHint locks the phone field to a device-sourced number',
    () async {
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
          localeStorageProvider.overrideWithValue(_FakeLocaleStorage()),
          phoneHintServiceProvider.overrideWithValue(
            _FakePhoneHintService(isSupported: true, hint: '+2250700000003'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier);

      await controller.requestPhoneHint();

      final state = container.read(onboardingControllerProvider);
      expect(state.phone, '+2250700000003');
      expect(state.phoneLocked, isTrue);
    },
  );

  test(
    'requestPhoneHint with no result leaves the field unlocked for manual entry',
    () async {
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
          localeStorageProvider.overrideWithValue(_FakeLocaleStorage()),
          phoneHintServiceProvider.overrideWithValue(
            _FakePhoneHintService(isSupported: true, hint: null),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier);

      await controller.requestPhoneHint();

      final state = container.read(onboardingControllerProvider);
      expect(state.phoneLocked, isFalse);
    },
  );

  test(
    'confirmCode logs straight into an existing account instead of registering',
    () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiClient()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
          sessionStorageProvider.overrideWithValue(_FakeSessionStorage()),
          localeStorageProvider.overrideWithValue(_FakeLocaleStorage()),
          phoneHintServiceProvider.overrideWithValue(_FakePhoneHintService()),
        ],
      );
      addTearDown(container.dispose);
      final onboarding = container.read(onboardingControllerProvider.notifier);
      onboarding.selectRole(UserRole.client);
      onboarding.setDistrict(_fakeDistrict);
      onboarding.setPhone(_alreadyRegisteredPhone);

      final verified = await container
          .read(otpControllerProvider.notifier)
          .confirmCode(_alreadyRegisteredPhone, _correctOtpCode);

      expect(verified, isTrue);
      final state = container.read(onboardingControllerProvider);
      expect(state.loggedIntoExistingAccount, isTrue);
      expect(state.isPhoneVerified, isTrue);
      expect(state.registrationToken, isNull);
    },
  );

  test('confirmCode stores a registrationToken for a brand-new phone', () async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient()),
        tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        sessionStorageProvider.overrideWithValue(_FakeSessionStorage()),
        localeStorageProvider.overrideWithValue(_FakeLocaleStorage()),
        phoneHintServiceProvider.overrideWithValue(_FakePhoneHintService()),
      ],
    );
    addTearDown(container.dispose);
    final onboarding = container.read(onboardingControllerProvider.notifier);
    onboarding.setPhone('+2250700000042');

    final verified = await container
        .read(otpControllerProvider.notifier)
        .confirmCode('+2250700000042', _correctOtpCode);

    expect(verified, isTrue);
    final state = container.read(onboardingControllerProvider);
    expect(state.loggedIntoExistingAccount, isFalse);
    expect(state.registrationToken, 'fake-registration-token');
    expect(state.isPhoneVerified, isTrue);
  });
}
