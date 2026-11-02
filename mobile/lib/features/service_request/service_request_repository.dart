import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';
import 'service_request_state.dart';

class ActiveRequest {
  const ActiveRequest({
    required this.requestId,
    required this.serviceCategory,
    required this.status,
    required this.craftsmanId,
    required this.craftsmanFullName,
    required this.craftsmanPhone,
  });

  final String requestId;
  final ServiceCategory serviceCategory;
  final ServiceRequestStatus status;
  // Backs the Report/Block action once a craftsman is assigned — see
  // ReportBlockMenu.
  final String? craftsmanId;
  final String? craftsmanFullName;
  final String? craftsmanPhone;
}

// One of the nearest craftsmen offered to contact directly once the 75s
// matching window closes with nobody accepting — see the backend's
// FallbackContactsService.
class FallbackCraftsman {
  const FallbackCraftsman({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.distanceMeters,
    required this.averageRating,
    required this.ratingsCount,
    required this.completedJobsCount,
    required this.isOnline,
  });

  factory FallbackCraftsman.fromJson(Map<String, dynamic> json) =>
      FallbackCraftsman(
        id: json['id'] as String,
        fullName: json['fullName'] as String?,
        phone: json['phone'] as String,
        distanceMeters: (json['distanceMeters'] as num).toInt(),
        averageRating: (json['averageRating'] as num?)?.toDouble(),
        ratingsCount: json['ratingsCount'] as int,
        completedJobsCount: json['completedJobsCount'] as int,
        isOnline: json['isOnline'] as bool,
      );

  final String id;
  final String? fullName;
  final String phone;
  final int distanceMeters;
  final double? averageRating;
  final int ratingsCount;
  final int completedJobsCount;
  final bool isOnline;
}

class FallbackList {
  const FallbackList({
    required this.serviceCategory,
    required this.clientDistrictName,
    required this.craftsmen,
  });

  final ServiceCategory serviceCategory;
  final String? clientDistrictName;
  final List<FallbackCraftsman> craftsmen;
}

enum ContactChannel {
  whatsapp('whatsapp'),
  call('call');

  const ContactChannel(this.wireValue);
  final String wireValue;
}

class ServiceRequestRepository {
  ServiceRequestRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<String> createRequest({
    required ServiceCategory category,
    required double latitude,
    required double longitude,
    String? destinationAddress,
    String? loadDetails,
  }) async {
    final response = await _apiClient.post('/matching/requests', {
      'serviceCategory': category.wireValue,
      'latitude': latitude,
      'longitude': longitude,
      if (destinationAddress != null && destinationAddress.isNotEmpty)
        'destinationAddress': destinationAddress,
      if (loadDetails != null && loadDetails.isNotEmpty)
        'loadDetails': loadDetails,
    });
    return response['requestId'] as String;
  }

  Future<void> cancelRequest(String requestId) =>
      _apiClient.patch('/matching/requests/$requestId/cancel', const {});

  // Ground truth for "what's my request actually doing" — see
  // ServiceRequestController.handleAppResumed and resumeActiveRequest.
  // Mirrors CraftsmanHomeRepository.getActiveJob; null means no active
  // request.
  Future<ActiveRequest?> getActiveRequest() async {
    final response = await _apiClient.get('/clients/me/active-request');
    if (response.isEmpty) return null;
    return ActiveRequest(
      requestId: response['requestId'] as String,
      serviceCategory: ServiceCategory.values.firstWhere(
        (c) => c.wireValue == response['serviceCategory'],
        orElse: () => ServiceCategory.plumber,
      ),
      status: switch (response['status']) {
        'assigned' => ServiceRequestStatus.assigned,
        'in_progress' => ServiceRequestStatus.inProgress,
        'awaiting_client_confirmation' =>
          ServiceRequestStatus.awaitingClientConfirmation,
        _ => ServiceRequestStatus.searching,
      },
      craftsmanId: response['craftsmanId'] as String?,
      craftsmanFullName: response['craftsmanFullName'] as String?,
      craftsmanPhone: response['craftsmanPhone'] as String?,
    );
  }

  Future<FallbackList> getFallbackCraftsmen(String requestId) async {
    final response = await _apiClient.get(
      '/matching/requests/$requestId/fallback-craftsmen',
    );
    return FallbackList(
      serviceCategory: ServiceCategory.values.firstWhere(
        (c) => c.wireValue == response['serviceCategory'],
        orElse: () => ServiceCategory.plumber,
      ),
      clientDistrictName: response['clientDistrictName'] as String?,
      craftsmen: (response['craftsmen'] as List<dynamic>)
          .map((c) => FallbackCraftsman.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  // Logged server-side (admin "Ops live détaillée") and pushes the
  // craftsman a heads-up the first time — see FallbackContactsService.
  Future<void> recordContact(
    String requestId, {
    required String craftsmanId,
    required ContactChannel channel,
  }) => _apiClient.post('/matching/requests/$requestId/contacts', {
    'craftsmanId': craftsmanId,
    'channel': channel.wireValue,
  });

  Future<void> confirmCompletion(String requestId) => _apiClient.patch(
    '/matching/requests/$requestId/confirm-complete',
    const {},
  );

  Future<void> submitRating(
    String requestId, {
    required int stars,
    String? comment,
  }) => _apiClient.post('/matching/requests/$requestId/rating', {
    'stars': stars,
    if (comment != null && comment.isNotEmpty) 'comment': comment,
  });
}

final serviceRequestRepositoryProvider = Provider<ServiceRequestRepository>(
  (ref) => ServiceRequestRepository(ref.watch(apiClientProvider)),
);

// Backs the "you have an unfinished mission" banner on the client Home
// screen — the fix for a client leaving the request-tracking screen (Home,
// app restart, a push-notification tap that lands on the shell rather than
// the live-tracking screen) and having no way back to a request that's
// still active server-side. Refetches on every fresh watch (Home re-mount)
// and whenever ClientShellScreen invalidates it on app resume.
final clientActiveRequestNoticeProvider = FutureProvider.autoDispose<
  ActiveRequest?
>((ref) => ref.read(serviceRequestRepositoryProvider).getActiveRequest());
