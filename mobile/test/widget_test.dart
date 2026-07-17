import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app.dart';

void main() {
  testWidgets(
    'onboarding flow: splash -> role selection -> registration -> success',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: FixCiApp()));

      // Splash screen shown immediately.
      expect(find.text('FixCi'), findsOneWidget);

      // Wait past the splash timer.
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Role selection screen.
      expect(find.text('Qui êtes-vous ?'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('Artisan'), findsOneWidget);

      await tester.tap(find.text('Client'));
      await tester.pump();

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      // Registration screen (client: no service-category field).
      expect(find.text('Vos informations'), findsOneWidget);
      expect(find.text('Catégorie de service'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Numéro de téléphone'),
        '+2250700000000',
      );
      await tester.pump();

      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      // Success screen.
      expect(find.text('Bienvenue !'), findsOneWidget);
    },
  );

  testWidgets('craftsman registration requires a service category', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FixCiApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.text('Artisan'));
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Votre profil artisan'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Numéro de téléphone'),
      '+2250700000000',
    );
    await tester.pump();

    // Submit button stays disabled until a service category is picked.
    final submitButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text("S'inscrire"),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(submitButton.onPressed, isNull);

    await tester.tap(find.text('Catégorie de service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plombier').last);
    await tester.pumpAndSettle();

    final enabledSubmitButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text("S'inscrire"),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(enabledSubmitButton.onPressed, isNotNull);
  });
}
