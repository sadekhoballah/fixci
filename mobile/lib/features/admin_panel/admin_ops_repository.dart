import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_ops_state.dart';

class AdminOpsRepository {
  AdminOpsRepository(this._apiClient);

  final AdminApiClient _apiClient;

  Future<List<OnlineCraftsman>> getPresence() async {
    final response = await _apiClient.get('/admin/ops/presence');
    return (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      final onlineSince = json['onlineSince'] as String?;
      return OnlineCraftsman(
        craftsmanId: json['craftsmanId'] as String,
        fullName: json['fullName'] as String?,
        phone: json['phone'] as String,
        category: json['category'] as String,
        districtName: json['districtName'] as String,
        onlineSince: onlineSince == null ? null : DateTime.parse(onlineSince),
      );
    }).toList();
  }

  Future<OpsStats> getStats(OpsStatsRange range) async {
    final response = await _apiClient.get(
      '/admin/ops/stats?range=${range.apiValue}',
    );
    return OpsStats(
      byStatus: (response['byStatus'] as List)
          .map(
            (raw) => StatusCount(
              status: (raw as Map<String, dynamic>)['status'] as String,
              count: raw['count'] as int,
            ),
          )
          .toList(),
      byDistrict: (response['byDistrict'] as List)
          .map(
            (raw) => NamedCount(
              name: (raw as Map<String, dynamic>)['districtName'] as String,
              count: raw['count'] as int,
            ),
          )
          .toList(),
      byCategory: (response['byCategory'] as List)
          .map(
            (raw) => NamedCount(
              name: (raw as Map<String, dynamic>)['category'] as String,
              count: raw['count'] as int,
            ),
          )
          .toList(),
    );
  }
}

final adminOpsRepositoryProvider = Provider<AdminOpsRepository>(
  (ref) => AdminOpsRepository(ref.watch(adminApiClientProvider)),
);
