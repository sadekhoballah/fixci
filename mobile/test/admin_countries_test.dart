import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/admin_panel/admin_countries.dart';

void main() {
  test('flags and labels for launched countries', () {
    expect(countryFlag('SN'), '🇸🇳');
    expect(countryFlag('CI'), '🇨🇮');
    expect(countryLabel('CD'), 'RD Congo');
    expect(adminCountries.length, 13);
  });

  testWidgets('the AppBar filter narrows the whole panel to one country', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AdminCountryFilterButton()),
        ),
      ),
    );
    expect(find.text('🌍 Tous les pays'), findsOneWidget);

    await tester.tap(find.byType(AdminCountryFilterButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇸🇳 Sénégal').last);
    await tester.pumpAndSettle();

    expect(container.read(adminCountryFilterProvider), 'SN');
    expect(find.text('🇸🇳 Sénégal'), findsOneWidget);
  });
}
