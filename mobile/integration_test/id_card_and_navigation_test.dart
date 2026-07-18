import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mobile/app.dart';
import 'package:mobile/core/media/id_card_picker.dart';

// See registration_flow_test.dart for why this uses bounded pump() loops
// instead of pumpAndSettle() (no virtual clock on a real device target).
Future<void> settle(
  WidgetTester tester, {
  int steps = 3,
  Duration step = const Duration(seconds: 1),
}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(step);
  }
}

// A tiny real 1x1 PNG, base64-encoded — stands in for whatever the OS
// picker/camera would normally return. The native file/camera dialogs can't
// be driven by an automated test (on any platform), so this fakes only that
// one boundary; everything downstream (upload, DTO wiring, backend, DB) is
// exercised for real against localhost:3000.
const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+A8AAQUBAScY42YAAAAASUVORK5CYII=';

class _FakeIdCardPicker implements IdCardPicker {
  @override
  Future<PickedImage?> pickFromGallery() async => PickedImage(
    bytes: base64Decode(_tinyPngBase64),
    filename: 'fake-id-card.png',
    mimeType: 'image/png',
  );

  @override
  Future<PickedImage?> pickFromCamera() => pickFromGallery();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(
    5,
  );

  testWidgets('client registration navigates to the client home screen', (
    tester,
  ) async {
    final phone = '+225071${suffix}1';
    await tester.pumpWidget(const ProviderScope(child: FixCiApp()));
    await settle(tester, steps: 3);

    await tester.tap(find.text('Client'));
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await settle(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Numéro de téléphone'),
      phone,
    );
    await tester.pump();
    await tester.tap(find.text("S'inscrire"));
    await settle(tester, steps: 5);

    expect(find.text('Bienvenue !'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await settle(tester);

    expect(find.text('De quoi avez-vous besoin ?'), findsOneWidget);
    expect(find.text('Plombier'), findsOneWidget);

    // Back button shouldn't return into the onboarding flow.
    expect(find.text("S'inscrire"), findsNothing);
  });

  testWidgets(
    'craftsman registration with an id card upload navigates to the dashboard',
    (tester) async {
      final phone = '+225071${suffix}2';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            idCardPickerProvider.overrideWithValue(_FakeIdCardPicker()),
          ],
          child: const FixCiApp(),
        ),
      );
      await settle(tester, steps: 3);

      await tester.tap(find.text('Artisan'));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await settle(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Numéro de téléphone'),
        phone,
      );
      await tester.tap(find.text('Catégorie de service'));
      await settle(tester);
      await tester.tap(find.text('Peintre').last);
      await settle(tester);

      // Attach the ID card via the fake picker.
      await tester.tap(find.text("Ajouter votre pièce d'identité"));
      await settle(tester);
      await tester.tap(find.text('Choisir depuis la galerie'));
      await settle(tester, steps: 5);

      expect(
        find.text("Pièce d'identité ajoutée"),
        findsOneWidget,
        reason:
            'Expected the real upload to succeed and flip to attached state',
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.text("S'inscrire"));
      await settle(tester, steps: 5);

      expect(find.text('Bienvenue !'), findsOneWidget);
      await tester.tap(find.text('Continuer'));
      await settle(tester);

      expect(find.text('En attente de demandes'), findsOneWidget);
    },
  );
}
