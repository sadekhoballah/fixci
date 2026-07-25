import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';

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
