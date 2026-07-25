import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';
import 'client_jobs_state.dart';

class ClientJobsRepository {
  ClientJobsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<RequestHistoryPage> getRequests({
    required int limit,
    required int offset,
  }) async {
    final response = await _apiClient.get(
      '/clients/me/requests?limit=$limit&offset=$offset',
    );
    final items = (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      return RequestHistoryEntry(
        requestId: json['requestId'] as String,
        serviceCategory: ServiceCategory.values.firstWhere(
          (c) => c.wireValue == json['serviceCategory'],
          orElse: () => ServiceCategory.plumber,
        ),
        status: parseRequestHistoryStatus(json['status'] as String),
        craftsmanFullName: json['craftsmanFullName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        ratingStars: (json['ratingStars'] as num?)?.toInt(),
      );
    }).toList();
    return RequestHistoryPage(items: items, hasMore: response['hasMore'] as bool);
  }
}

class RequestHistoryPage {
  const RequestHistoryPage({required this.items, required this.hasMore});

  final List<RequestHistoryEntry> items;
  final bool hasMore;
}

final clientJobsRepositoryProvider = Provider<ClientJobsRepository>(
  (ref) => ClientJobsRepository(ref.watch(apiClientProvider)),
);
