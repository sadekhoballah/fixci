import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app.dart';
import 'package:mobile/core/auth/phone_verification_provider.dart';
import 'package:mobile/core/auth/phone_verification_service.dart';
import 'package:mobile/core/auth/session_storage.dart';
import 'package:mobile/core/localization/locale_storage.dart';
import 'package:mobile/core/media/id_card_picker.dart';
import 'package:mobile/core/models/subscription_tier.dart';
import 'package:mobile/core/models/user_role.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/onboarding/onboarding_controller.dart';
import 'package:mobile/l10n/app_localizations.dart';

// A real 400x300 PNG — plausible ID-card-ish dimensions, passes validation
// (mirrors the constant in widget_test.dart).
const _plausibleIdCardPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAZAAAAEsAQMAAADXeXeBAAAAIGNIUk0AAHomAACAhAAA'
    '+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGUExURYfO6/////E3Kz4AAAABYkt'
    'HRAH/Ai3eAAAAB3RJTUUH6gcSCyoLx9crAQAAACZJREFUaN7twTEBAAAAwqD1T20JT6'
    'AAAAAAAAAAAAAAAAAAAICnATvEAAEnf54JAAAAAElFTkSuQmCC';

const _correctCode = '123456';

// Fakes only the true I/O boundary (mirrors _FakeApiClient/_FakeIdCardPicker
// in widget_test.dart) — everything above it (OtpController, OnboardingController,
// the screens) runs for real.
class _FakePhoneVerificationService implements PhoneVerificationService {
  _FakePhoneVerificationService({this.failSend = false});

  final bool failSend;
  int sendCodeCallCount = 0;

  @override
  Future<void> sendCode({
    required String phoneNumber,
    required void Function(CodeSentResult result) onCodeSent,
    required void Function(String idToken) onAutoVerified,
    required void Function(PhoneVerificationException error) onFailed,
  }) async {
    sendCodeCallCount++;
    if (failSend) {
      onFailed(
        PhoneVerificationException(PhoneVerificationError.invalidPhoneNumber),
      );
      return;
    }
    onCodeSent(CodeSentResult(verificationId: 'fake-verification-id'));
  }

  @override
  Future<String?> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (smsCode != _correctCode) {
      throw PhoneVerificationException(PhoneVerificationError.invalidCode);
    }
    return 'fake-id-token';
  }
}

class _FakeApiClient extends ApiClient {
  // These tests assert against the app's default French copy (no locale
  // override in buildApp) — just satisfies ApiClient's now-required l10n
  // constructor param for the fallback messages this fake never triggers.
  _FakeApiClient() : super(l10n: lookupAppLocalizations(const Locale('fr')));

  // completeAfterVerification() checks for an existing account before
  // registering — 404 here means "no account yet", the expected case for a
  // fresh registration test.
  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path == '/users/lookup') {
      throw ApiException('No account with this phone number', statusCode: 404);
    }
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
      return {
        'id': 'fake-user-id',
        'phone': body['phone'],
        'fullName': body['fullName'],
        'role': body['role'],
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

void main() {
  Widget buildApp(PhoneVerificationService phoneService) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient()),
        phoneVerificationServiceProvider.overrideWithValue(phoneService),
        idCardPickerProvider.overrideWithValue(_FakeIdCardPicker()),
        sessionStorageProvider.overrideWithValue(_FakeSessionStorage()),
        localeStorageProvider.overrideWithValue(_FakeLocaleStorage()),
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

  Future<void> goToOtpScreen(WidgetTester tester, {String phone = '+2250700000099'}) async {
    await tester.pumpWidget(buildApp(_FakePhoneVerificationService()));
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
      phone,
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

  testWidgets('correct code verifies the phone and completes registration', (
    tester,
  ) async {
    await goToOtpScreen(tester);
    expect(find.text('Vérification du numéro'), findsOneWidget);

    await tester.enterText(find.byType(TextField), _correctCode);
    await tester.pump();
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue, Aya Kone !'), findsOneWidget);
  });

  testWidgets('wrong code shows an inline error and stays on the OTP screen', (
    tester,
  ) async {
    await goToOtpScreen(tester);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();

    expect(find.text('Vérification du numéro'), findsOneWidget);
    expect(find.text('Code incorrect. Veuillez réessayer.'), findsOneWidget);

    // Correcting the code afterwards still works — the failure didn't
    // burn the verification session.
    await tester.enterText(find.byType(TextField), _correctCode);
    await tester.pump();
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue, Aya Kone !'), findsOneWidget);
  });

  testWidgets('resend is disabled during the cooldown window', (
    tester,
  ) async {
    await goToOtpScreen(tester);

    final resendButton = find.byType(TextButton);
    expect(resendButton, findsOneWidget);
    expect(
      tester.widget<TextButton>(resendButton).onPressed,
      isNull,
      reason: 'Resend should be disabled immediately after a code is sent',
    );
    expect(find.textContaining('Renvoyer le code ('), findsOneWidget);
  });

  testWidgets('a failed send shows an inline error with a retry option', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(_FakePhoneVerificationService(failSend: true)),
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
      '+2250700000098',
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Votre zone / commune'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cocody').last);
    await tester.pumpAndSettle();
    await attachIdCard(tester);

    await tester.ensureVisible(find.text("S'inscrire"));
    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();

    expect(find.text('Numéro de téléphone invalide.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  test('editing the phone after verifying it clears the verification', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(onboardingControllerProvider.notifier);

    controller.setPhone('+2250700000001');
    controller.setVerifiedPhone(
      phone: '+2250700000001',
      idToken: 'fake-id-token',
    );
    expect(container.read(onboardingControllerProvider).isPhoneVerified, isTrue);

    controller.setPhone('+2250700000002');
    final state = container.read(onboardingControllerProvider);
    expect(state.isPhoneVerified, isFalse);
    expect(state.firebaseIdToken, isNull);
  });
}
