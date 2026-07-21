import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app.dart';
import 'package:mobile/core/auth/dev_bypass_phone_verification_service.dart';
import 'package:mobile/core/auth/session_storage.dart';
import 'package:mobile/core/media/id_card_picker.dart';
import 'package:mobile/core/models/subscription_tier.dart';
import 'package:mobile/core/models/user_role.dart';
import 'package:mobile/core/network/api_client.dart';

// Running under `flutter test` on this Linux dev machine, isFirebaseSupportedPlatform
// is false and kDebugMode is true, so phoneVerificationServiceProvider naturally
// resolves to DevBypassPhoneVerificationService — no override needed. This
// drives the OTP screen exactly the way it behaves for real on this platform.
Future<void> _verifyPhoneViaOtp(WidgetTester tester) async {
  expect(find.text('Vérification du numéro'), findsOneWidget);
  await tester.enterText(find.byType(TextField), devBypassCode);
  await tester.pump();
  await tester.tap(find.text('Vérifier'));
  await tester.pumpAndSettle();
}

// A real 1x1 PNG — decodable, but far below the minimum ID-card dimension,
// so it exercises the "image too small" client-side validation path.
const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+A8AAQUBAScY42YAAAAASUVORK5CYII=';

// dart:ui's image codec decode (used by validateIdCardImage) resolves via a
// native engine callback that doesn't reliably trigger pumpAndSettle's
// frame-scheduling detection, so pumpAndSettle can return before the decode
// actually finishes. runAsync bridges real async engine work into the
// test's pump loop, which is the standard fix for this class of flake.
Future<void> _waitForAsyncImageWork(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

// A real 400x300 PNG — plausible ID-card-ish dimensions, passes validation.
const _plausibleIdCardPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAZAAAAEsAQMAAADXeXeBAAAAIGNIUk0AAHomAACAhAAA'
    '+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGUExURYfO6/////E3Kz4AAAABYkt'
    'HRAH/Ai3eAAAAB3RJTUUH6gcSCyoLx9crAQAAACZJREFUaN7twTEBAAAAwqD1T20JT6'
    'AAAAAAAAAAAAAAAAAAAICnATvEAAEnf54JAAAAAElFTkSuQmCC';

// Fakes only the true I/O boundary (network transport), so every layer above
// it — OnboardingRepository's field/enum-wire-value mapping, the controller,
// the widgets — runs for real. The actual backend contract (field names,
// status codes, response shapes) is separately verified against the live
// NestJS server, not re-asserted here.
class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.failRegister = false, this.failUpload = false});

  final bool failRegister;
  final bool failUpload;
  int multipartCallCount = 0;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path == '/users/register') {
      if (failRegister) {
        throw ApiException(
          'Phone number already registered',
          statusCode: 409,
        );
      }
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
    multipartCallCount++;
    if (path == '/uploads/id-card') {
      if (failUpload) {
        throw ApiException('Only JPEG or PNG images are allowed');
      }
      return {'storageKey': 'id-cards/fake.png'};
    }
    throw UnimplementedError('Unexpected path in fake client: $path');
  }
}

class _FakeIdCardPicker implements IdCardPicker {
  _FakeIdCardPicker({this.tooSmall = false});

  final bool tooSmall;

  @override
  Future<PickedImage?> pickFromGallery() async => PickedImage(
    bytes: base64Decode(tooSmall ? _tinyPngBase64 : _plausibleIdCardPngBase64),
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

void main() {
  Widget buildApp({
    _FakeApiClient? apiClient,
    bool failRegister = false,
    bool failUpload = false,
    bool tooSmallIdCard = false,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(
          apiClient ??
              _FakeApiClient(failRegister: failRegister, failUpload: failUpload),
        ),
        idCardPickerProvider.overrideWithValue(
          _FakeIdCardPicker(tooSmall: tooSmallIdCard),
        ),
        sessionStorageProvider.overrideWithValue(_FakeSessionStorage()),
      ],
      child: const FixCiApp(),
    );
  }

  Future<void> fillIdentity(
    WidgetTester tester, {
    required String phone,
  }) async {
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
  }

  Future<void> attachIdCard(WidgetTester tester) async {
    await tester.ensureVisible(find.text("Ajouter votre pièce d'identité"));
    await tester.tap(find.text("Ajouter votre pièce d'identité"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir depuis la galerie'));
    await _waitForAsyncImageWork(tester);
  }

  testWidgets(
    'client registration succeeds and navigates to the client home screen',
    (tester) async {
      await tester.pumpWidget(buildApp());

      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.text('Qui êtes-vous ?'), findsOneWidget);

      await tester.tap(find.text('Client'));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Vos informations'), findsOneWidget);
      expect(find.text('Catégorie de service'), findsNothing);

      await fillIdentity(tester, phone: '+2250700000000');
      await attachIdCard(tester);

      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();
      await _verifyPhoneViaOtp(tester);

      expect(find.text('Bienvenue, Aya Kone !'), findsOneWidget);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('De quoi avez-vous besoin ?'), findsOneWidget);
      expect(find.text('Plombier'), findsOneWidget);
      // Onboarding stack was cleared — no way back into the form.
      expect(find.text("S'inscrire"), findsNothing);
    },
  );

  testWidgets(
    'craftsman registration requires a service category before submitting',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.tap(find.text('Artisan'));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Votre profil artisan'), findsOneWidget);

      await fillIdentity(tester, phone: '+2250700000000');
      await tester.enterText(
        find.widgetWithText(TextField, 'Expérience'),
        "5 ans d'expérience en plomberie",
      );
      await tester.pump();
      await attachIdCard(tester);

      final disabledButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text("S'inscrire"),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(disabledButton.onPressed, isNull);

      await tester.tap(find.text('Catégorie de service'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plombier').last);
      await tester.pumpAndSettle();

      final enabledButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text("S'inscrire"),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(enabledButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'craftsman can attach an id card and it uploads before submitting',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.tap(find.text('Artisan'));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      await fillIdentity(tester, phone: '+2250700000001');
      await tester.enterText(
        find.widgetWithText(TextField, 'Expérience'),
        "5 ans d'expérience en électricité",
      );
      await tester.tap(find.text('Catégorie de service'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Électricien').last);
      await tester.pumpAndSettle();

      expect(find.text("Ajouter votre pièce d'identité"), findsOneWidget);

      await attachIdCard(tester);

      expect(find.text("Pièce d'identité ajoutée"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();
      await _verifyPhoneViaOtp(tester);

      expect(find.text('Bienvenue, Aya Kone !'), findsOneWidget);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Choisissez la formule qui vous convient'),
        findsOneWidget,
      );

      await tester.tap(find.text('Débutant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('En attente de demandes'), findsOneWidget);
    },
  );

  testWidgets(
    'id card client-side validation rejects an implausibly small image '
    'without ever calling the upload endpoint',
    (tester) async {
      final apiClient = _FakeApiClient();
      await tester.pumpWidget(
        buildApp(apiClient: apiClient, tooSmallIdCard: true),
      );
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.tap(find.text('Artisan'));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Ajouter votre pièce d'identité"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir depuis la galerie'));
      await _waitForAsyncImageWork(tester);

      expect(find.text("Pièce d'identité ajoutée"), findsNothing);
      expect(
        find.text('La résolution de l\'image est trop faible pour être lisible.'),
        findsOneWidget,
      );
      expect(
        apiClient.multipartCallCount,
        0,
        reason: 'Validation should reject before any network call is made',
      );
    },
  );

  testWidgets(
    'id card upload failure shows an inline error and does not mark attached',
    (tester) async {
      await tester.pumpWidget(buildApp(failUpload: true));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.tap(find.text('Artisan'));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Ajouter votre pièce d'identité"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir depuis la galerie'));
      await _waitForAsyncImageWork(tester);

      expect(find.text("Pièce d'identité ajoutée"), findsNothing);
      expect(
        find.text('Only JPEG or PNG images are allowed'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'registration failure shows a server error after phone verification '
    'succeeds, and stays on the OTP screen',
    (tester) async {
      await tester.pumpWidget(buildApp(failRegister: true));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.tap(find.text('Client'));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      await fillIdentity(tester, phone: '+2250700000000');
      await attachIdCard(tester);

      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();
      await _verifyPhoneViaOtp(tester);

      // Phone verification itself succeeded (dev bypass); the subsequent
      // POST /users/register call is what fails here.
      expect(find.text('Vérification du numéro'), findsOneWidget);
      expect(find.text('Phone number already registered'), findsOneWidget);
    },
  );
}
