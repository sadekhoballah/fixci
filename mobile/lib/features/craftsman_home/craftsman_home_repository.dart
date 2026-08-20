import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/media/id_card_picker.dart';
import '../../core/models/service_category.dart';
import '../../core/models/subscription_tier.dart';
import '../../core/network/api_client.dart';
import 'craftsman_home_state.dart';
import 'live_requests_state.dart';

class CraftsmanMe {
  const CraftsmanMe({
    required this.fullName,
    required this.tier,
    required this.daysRemaining,
    required this.isAvailable,
    required this.averageRating,
    required this.ratingsCount,
    required this.serviceCategory,
    required this.idVerified,
    required this.isActive,
    required this.countryCode,
  });

  final String? fullName;
  final SubscriptionTier tier;
  final int? daysRemaining;
  final bool isAvailable;
  final double? averageRating;
  final int ratingsCount;
  final ServiceCategory serviceCategory;
  final bool idVerified;
  final bool isActive;
  final String countryCode;
}

class CraftsmanHomeRepository {
  CraftsmanHomeRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CraftsmanMe> getMe() async {
    final response = await _apiClient.get('/craftsmen/me');
    return CraftsmanMe(
      fullName: response['fullName'] as String?,
      tier: _parseTier(response['subscriptionTier'] as String),
      daysRemaining: response['daysRemaining'] as int?,
      isAvailable: response['isAvailable'] as bool,
      averageRating: (response['averageRating'] as num?)?.toDouble(),
      ratingsCount: response['ratingsCount'] as int,
      serviceCategory: _parseCategory(response['serviceCategory'] as String),
      idVerified: response['idVerified'] as bool,
      isActive: response['isActive'] as bool,
      countryCode: response['countryCode'] as String,
    );
  }

  // Same two-step shape as OnboardingRepository.uploadIdCard +
  // registerUser's idCardStorageKey: get a storage key from the (already
  // rate-limited/validated) public upload endpoint, then attach it — here,
  // to an existing profile instead of a not-yet-created one.
  Future<String> uploadIdCard(PickedImage image) async {
    final response = await _apiClient.postMultipart(
      '/uploads/id-card',
      'file',
      image.bytes,
      image.filename,
      contentTypeHeader: image.mimeType,
    );
    return response['storageKey'] as String;
  }

  Future<void> resubmitIdCard(String storageKey) =>
      _apiClient.patch('/craftsmen/me/id-card', {
        'idCardStorageKey': storageKey,
      });

  Future<bool> setAvailability(
    bool available, {
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.patch('/craftsmen/me/availability', {
      'available': available,
      'latitude': ?latitude,
      'longitude': ?longitude,
    });
    return response['isAvailable'] as bool;
  }

  Future<CraftsmanHomeStats> getStats() async {
    final response = await _apiClient.get('/craftsmen/me/stats');
    return CraftsmanHomeStats(
      jobsDoneToday: response['jobsDoneToday'] as int,
      jobsAssignedToday: response['jobsAssignedToday'] as int,
      avgResponseSeconds: (response['avgResponseSeconds'] as num?)?.round(),
    );
  }

  Future<ActiveJob?> getActiveJob() async {
    final response = await _apiClient.get('/craftsmen/me/active-job');
    if (response.isEmpty) return null;
    return ActiveJob(
      requestId: response['requestId'] as String,
      serviceCategory: _parseCategory(response['serviceCategory'] as String),
      status: switch (response['status']) {
        'in_progress' => ActiveJobStatus.inProgress,
        'awaiting_client_confirmation' =>
          ActiveJobStatus.awaitingClientConfirmation,
        _ => ActiveJobStatus.assigned,
      },
      clientId: response['clientId'] as String,
      clientFullName: response['clientFullName'] as String?,
      clientPhone: response['clientPhone'] as String,
      clientLatitude: (response['clientLatitude'] as num).toDouble(),
      clientLongitude: (response['clientLongitude'] as num).toDouble(),
      assignedAt: DateTime.parse(response['assignedAt'] as String),
      startedAt: response['startedAt'] == null
          ? null
          : DateTime.parse(response['startedAt'] as String),
    );
  }

  Future<void> startJob(String requestId) =>
      _apiClient.patch('/matching/requests/$requestId/start', const {});

  Future<void> completeJob(String requestId) =>
      _apiClient.patch('/matching/requests/$requestId/complete', const {});

  Future<void> cancelJob(String requestId) =>
      _apiClient.patch('/matching/requests/$requestId/cancel', const {});

  SubscriptionTier _parseTier(String wireValue) => switch (wireValue) {
    'bronze' => SubscriptionTier.bronze,
    'silver' => SubscriptionTier.silver,
    'gold' => SubscriptionTier.gold,
    _ => SubscriptionTier.free,
  };

  ServiceCategory _parseCategory(String wireValue) => ServiceCategory.values
      .firstWhere((c) => c.wireValue == wireValue, orElse: () => ServiceCategory.plumber);
}

final craftsmanHomeRepositoryProvider = Provider<CraftsmanHomeRepository>(
  (ref) => CraftsmanHomeRepository(ref.watch(apiClientProvider)),
);
