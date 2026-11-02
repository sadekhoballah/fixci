import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/auth/token_storage.dart';
import 'package:mobile/core/models/service_category.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/realtime/matching_socket_service.dart';
import 'package:mobile/features/service_request/service_request_repository.dart';
import 'package:mobile/features/service_request/widgets/fallback_craftsmen_panel.dart';
import 'package:mobile/l10n/app_localizations.dart';

class _FakeRepository extends ServiceRequestRepository {
  _FakeRepository(this._list)
    : super(
        ApiClient(
          l10n: lookupAppLocalizations(const Locale('fr')),
          tokenStorage: TokenStorage(),
        ),
      );

  final FallbackList? _list;

  @override
  Future<FallbackList> getFallbackCraftsmen(String requestId) async {
    final list = _list;
    if (list == null) throw ApiException('Demande introuvable');
    return list;
  }
}

const _list = FallbackList(
  serviceCategory: ServiceCategory.plumber,
  clientDistrictName: 'Cocody',
  craftsmen: [
    FallbackCraftsman(
      id: 'a',
      fullName: 'Kofi Yao',
      phone: '+2250700000001',
      distanceMeters: 1234,
      averageRating: 4.5,
      ratingsCount: 12,
      completedJobsCount: 9,
      isOnline: true,
    ),
    FallbackCraftsman(
      id: 'b',
      fullName: 'Aya Kone',
      phone: '+2250700000002',
      distanceMeters: 3500,
      averageRating: null,
      ratingsCount: 0,
      completedJobsCount: 0,
      isOnline: false,
    ),
  ],
);

Widget _panel(FallbackList? list, {VoidCallback? onRetry}) => ProviderScope(
  overrides: [
    serviceRequestRepositoryProvider.overrideWithValue(_FakeRepository(list)),
  ],
  child: MaterialApp(
    locale: const Locale('fr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: SingleChildScrollView(
        child: FallbackCraftsmenPanel(
          requestId: 'req-1',
          category: ServiceCategory.plumber,
          onRetry: onRetry,
          onBackHome: () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('lists the nearest craftsmen with rating, distance and contact buttons', (
    tester,
  ) async {
    await tester.pumpWidget(_panel(_list, onRetry: () {}));
    await tester.pumpAndSettle();

    expect(find.text("Aucun artisan n'a accepté à temps"), findsOneWidget);
    expect(find.text('Kofi Yao'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    expect(find.text('4.5 (12)'), findsOneWidget);
    expect(find.text('En ligne'), findsOneWidget);
    // No rating yet → "Nouveau" instead of stars.
    expect(find.text('Aya Kone'), findsOneWidget);
    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNWidgets(2));
    expect(find.text('Appeler'), findsNWidgets(2));
    expect(find.text('Relancer la recherche'), findsOneWidget);
  });

  testWidgets('falls back to the plain "nobody available" outcome when the list fails', (
    tester,
  ) async {
    await tester.pumpWidget(_panel(null, onRetry: () {}));
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  test('an offer counts down from the backend-provided window, 18s if absent', () {
    final json = {
      'requestId': 'r',
      'serviceCategory': 'plumber',
      'distanceMeters': 1200,
      'estimatedArrivalMinutes': 3,
    };
    expect(
      IncomingRequestEvent.fromJson(json).respondWithin,
      const Duration(seconds: 18),
    );
    expect(
      IncomingRequestEvent.fromJson({
        ...json,
        'respondWithinSeconds': 75,
      }).respondWithin,
      const Duration(seconds: 75),
    );
  });
}
