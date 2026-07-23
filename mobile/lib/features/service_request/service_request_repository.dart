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
}

final serviceRequestRepositoryProvider = Provider<ServiceRequestRepository>(
  (ref) => ServiceRequestRepository(ref.watch(apiClientProvider)),
);
