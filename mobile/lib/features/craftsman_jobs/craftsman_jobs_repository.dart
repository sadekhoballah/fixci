import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';
import 'craftsman_jobs_state.dart';

class CraftsmanJobsRepository {
  CraftsmanJobsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<JobHistoryPage> getJobs({required int limit, required int offset}) async {
    final response = await _apiClient.get(
      '/craftsmen/me/jobs?limit=$limit&offset=$offset',
    );
    final items = (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      return JobHistoryEntry(
        requestId: json['requestId'] as String,
        serviceCategory: ServiceCategory.values.firstWhere(
          (c) => c.wireValue == json['serviceCategory'],
          orElse: () => ServiceCategory.plumber,
        ),
        status: parseJobHistoryStatus(json['status'] as String),
        clientFullName: json['clientFullName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        ratingStars: (json['ratingStars'] as num?)?.toInt(),
      );
    }).toList();
    return JobHistoryPage(items: items, hasMore: response['hasMore'] as bool);
  }
}

class JobHistoryPage {
  const JobHistoryPage({required this.items, required this.hasMore});

  final List<JobHistoryEntry> items;
  final bool hasMore;
}

final craftsmanJobsRepositoryProvider = Provider<CraftsmanJobsRepository>(
  (ref) => CraftsmanJobsRepository(ref.watch(apiClientProvider)),
);
