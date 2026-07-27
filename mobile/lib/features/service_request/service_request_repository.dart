import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';
import 'service_request_state.dart';

class ActiveRequest {
  const ActiveRequest({
    required this.requestId,
    required this.status,
    required this.craftsmanFullName,
    required this.craftsmanPhone,
  });

  final String requestId;
  final ServiceRequestStatus status;
  final String? craftsmanFullName;
  final String? craftsmanPhone;
}

class ServiceRequestRepository {
  ServiceRequestRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<String> createRequest({
    required ServiceCategory category,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _apiClient.post('/matching/requests', {
      'serviceCategory': category.wireValue,
      'latitude': latitude,
      'longitude': longitude,
    });
    return response['requestId'] as String;
  }

  Future<void> cancelRequest(String requestId) =>
      _apiClient.patch('/matching/requests/$requestId/cancel', const {});

  // Ground truth for "what's my request actually doing" — see
  // ServiceRequestController.handleAppResumed. Mirrors
  // CraftsmanHomeRepository.getActiveJob; null means no active request.
  Future<ActiveRequest?> getActiveRequest() async {
    final response = await _apiClient.get('/clients/me/active-request');
    if (response.isEmpty) return null;
    return ActiveRequest(
      requestId: response['requestId'] as String,
      status: switch (response['status']) {
        'assigned' => ServiceRequestStatus.assigned,
        'in_progress' => ServiceRequestStatus.inProgress,
        'awaiting_client_confirmation' =>
          ServiceRequestStatus.awaitingClientConfirmation,
        _ => ServiceRequestStatus.searching,
      },
      craftsmanFullName: response['craftsmanFullName'] as String?,
      craftsmanPhone: response['craftsmanPhone'] as String?,
    );
  }

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
