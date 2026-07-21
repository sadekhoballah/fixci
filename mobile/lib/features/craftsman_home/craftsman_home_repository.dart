import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/subscription_tier.dart';
import '../../core/network/api_client.dart';
import 'craftsman_home_state.dart';

class CraftsmanMe {
  const CraftsmanMe({
    required this.tier,
    required this.daysRemaining,
    required this.isAvailable,
    required this.averageRating,
    required this.ratingsCount,
  });

  final SubscriptionTier tier;
  final int? daysRemaining;
  final bool isAvailable;
  final double? averageRating;
  final int ratingsCount;
}

class CraftsmanHomeRepository {
  CraftsmanHomeRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CraftsmanMe> getMe(String phone) async {
    final response = await _apiClient.get(
      '/craftsmen/me?phone=${Uri.encodeQueryComponent(phone)}',
    );
    return CraftsmanMe(
      tier: _parseTier(response['subscriptionTier'] as String),
      daysRemaining: response['daysRemaining'] as int?,
      isAvailable: response['isAvailable'] as bool,
      averageRating: (response['averageRating'] as num?)?.toDouble(),
      ratingsCount: response['ratingsCount'] as int,
    );
  }

  Future<bool> setAvailability(
    String phone,
    bool available, {
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.patch('/craftsmen/me/availability', {
      'phone': phone,
      'available': available,
      'latitude': ?latitude,
      'longitude': ?longitude,
    });
    return response['isAvailable'] as bool;
  }

  Future<CraftsmanHomeStats> getStats(String phone) async {
    final response = await _apiClient.get(
      '/craftsmen/me/stats?phone=${Uri.encodeQueryComponent(phone)}',
    );
    return CraftsmanHomeStats(
      jobsDoneToday: response['jobsDoneToday'] as int,
      jobsAssignedToday: response['jobsAssignedToday'] as int,
      avgResponseSeconds: (response['avgResponseSeconds'] as num?)?.round(),
    );
  }

  SubscriptionTier _parseTier(String wireValue) => switch (wireValue) {
    'bronze' => SubscriptionTier.bronze,
    'silver' => SubscriptionTier.silver,
    'gold' => SubscriptionTier.gold,
    _ => SubscriptionTier.free,
  };
}

final craftsmanHomeRepositoryProvider = Provider<CraftsmanHomeRepository>(
  (ref) => CraftsmanHomeRepository(ref.watch(apiClientProvider)),
);
