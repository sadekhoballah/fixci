import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mobile/app.dart';

// Runs against the real backend (must be up on localhost:3000) with real
// network I/O — unlike `flutter test`, IntegrationTestWidgetsFlutterBinding
// does not stub HttpClient, so this proves the actual request/response path,
// not just that a request was attempted.
//
// Uses plain bounded pump() loops instead of pumpAndSettle(): on a real
// device/desktop target, pumpAndSettle can spin far longer than expected
// (there's no virtual clock), so a fixed step count keeps runs predictable.
Future<void> settle(
  WidgetTester tester, {
  int steps = 3,
  Duration step = const Duration(seconds: 1),
}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(step);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(
    5,
  );

  testWidgets('client registration reaches the real backend', (
    tester,
  ) async {
    final phone = '+225070${suffix}1';
    await tester.pumpWidget(const ProviderScope(child: FixCiApp()));
    await settle(tester, steps: 3);

    await tester.tap(find.text('Client'));
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await settle(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nom complet'),
      'Integration Test Client',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Numéro de téléphone'),
      phone,
    );
    await tester.pump();

    await tester.tap(find.text("S'inscrire"));
    await settle(tester, steps: 5);

    expect(
      find.text('Bienvenue, Integration Test Client !'),
      findsOneWidget,
      reason: 'Expected navigation to the success screen after a real '
          'successful POST /users/register',
    );
  });

  testWidgets('craftsman registration reaches the real backend', (
    tester,
  ) async {
    final phone = '+225070${suffix}2';
    await tester.pumpWidget(const ProviderScope(child: FixCiApp()));
    await settle(tester, steps: 3);

    await tester.tap(find.text('Artisan'));
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await settle(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nom complet'),
      'Integration Test Craftsman',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Numéro de téléphone'),
      phone,
    );
    await tester.tap(find.text('Catégorie de service'));
    await settle(tester);
    await tester.tap(find.text('Électricien').last);
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Expérience (facultatif)'),
      '3 ans en électricité',
    );
    await tester.pump();

    await tester.tap(find.text("S'inscrire"));
    await settle(tester, steps: 5);

    expect(
      find.text('Bienvenue, Integration Test Craftsman !'),
      findsOneWidget,
      reason: 'Expected navigation to the success screen after a real '
          'successful POST /users/register',
    );
  });

  testWidgets('duplicate phone shows a real error from the backend, no navigation', (
    tester,
  ) async {
    final phone = '+225070${suffix}1'; // same as the first test — now taken
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

    expect(find.text('Vos informations'), findsOneWidget);
    expect(find.textContaining('already registered'), findsOneWidget);
  });
}
