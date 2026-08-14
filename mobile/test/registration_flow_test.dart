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
import 'package:mobile/features/onboarding/onboarding_state.dart';
import 'package:mobile/l10n/app_localizations.dart';

const _fakeDistrict = District(
  id: 'fake-district-id',
  name: 'Cocody',
  countryCode: 'CI',
  isArtisanRegistrationActive: true,
  isClientOrderingActive: true,
);

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

// A phone number that POST /users/register (below) treats as already
// belonging to an existing account, to exercise the 409 branches of
// OnboardingController.completeRegistration. _alreadyRegisteredLocalNumber
// is what a test actually types into the field (see
// fillAndSubmitRegistrationForm); _alreadyRegisteredPhone is the resulting
// E.164 form (+225 dial code) the fake backend matches against.
const _alreadyRegisteredLocalNumber = '0700000099';
const _alreadyRegisteredPhone = '+225$_alreadyRegisteredLocalNumber';

// Fakes only the true I/O boundary (mirrors _FakeApiClient in
// widget_test.dart) — everything above it (OnboardingController, the
// screens) runs for real.
class _FakeApiClient extends ApiClient {
  // These tests assert against the app's default French copy (no locale
  // override in buildApp) — just satisfies ApiClient's now-required l10n/
  // tokenStorage constructor params for the fallback logic this fake never
  // triggers.
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
    if (path == '/users/register') {
      if (failRegister) {
        throw ApiException('Invalid phone number.');
      }
      if (body['phone'] == _alreadyRegisteredPhone) {
        throw ApiException('Phone number already registered', statusCode: 409);
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
    if (path == '/auth/reconnect') {
      if (body['phone'] != _alreadyRegisteredPhone) {
        throw ApiException('No account with this phone number', statusCode: 404);
      }
      return {
        'accessToken': 'fake-reconnect-access-token',
        'refreshToken': 'fake-reconnect-refresh-token',
        'user': {
          'id': 'fake-user-id',
          'phone': body['phone'],
          'fullName': 'Existing Artisan',
          'role': 'client',
          'subscriptionTier': null,
        },
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

  // localNumber is what a real user types: just the national digits, since
  // the "+225" dial code is already shown separately via the field's flag
  // prefix (typing a full "+225..." string into the underlying TextField
  // would double up the dial code in PhoneNumber.completeNumber).
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
    'a manually-entered phone number registers directly, with no OTP step',
    (tester) async {
      await fillAndSubmitRegistrationForm(tester, localNumber: '0700000001');

      expect(find.text('Bienvenue, Aya Kone !'), findsOneWidget);
    },
  );

  testWidgets('a failed registration shows an inline error and stays on the form', (
    tester,
  ) async {
    await fillAndSubmitRegistrationForm(
      tester,
      localNumber: '0700000002',
      apiClient: _FakeApiClient(failRegister: true),
    );

    expect(find.text('Invalid phone number.'), findsOneWidget);
    expect(find.text('Inscription'), findsOneWidget);
  });

  testWidgets(
    'a manually-typed number that is already registered shows a contact-support '
    'message instead of logging in',
    (tester) async {
      await fillAndSubmitRegistrationForm(
        tester,
        localNumber: _alreadyRegisteredLocalNumber,
      );

      expect(
        find.text(
          'Ce numéro est déjà associé à un compte. Contactez le support pour récupérer votre accès.',
        ),
        findsOneWidget,
      );
      // Never navigated away — a manually-typed number gets no free pass.
      expect(find.text('Inscription'), findsOneWidget);
    },
  );

  test(
    'requestPhoneHint locks the phone field to a device-sourced number',
    () async {
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
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
      expect(state.phoneSource, PhoneSource.deviceHint);
    },
  );

  test(
    'requestPhoneHint with no result leaves the field unlocked for manual entry',
    () async {
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
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
      expect(state.phoneSource, PhoneSource.manual);
    },
  );

  test(
    'completeRegistration reconnects automatically for a device-sourced number '
    'that is already registered',
    () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiClient()),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
          sessionStorageProvider.overrideWithValue(_FakeSessionStorage()),
          phoneHintServiceProvider.overrideWithValue(
            _FakePhoneHintService(
              isSupported: true,
              hint: _alreadyRegisteredPhone,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier);
      controller.selectRole(UserRole.client);
      controller.setDistrict(_fakeDistrict);

      await controller.requestPhoneHint();
      expect(
        container.read(onboardingControllerProvider).phoneSource,
        PhoneSource.deviceHint,
      );

      final succeeded = await controller.completeRegistration();

      expect(succeeded, isTrue);
      final state = container.read(onboardingControllerProvider);
      expect(state.loggedIntoExistingAccount, isTrue);
      expect(state.registrationSucceeded, isTrue);
    },
  );
}
