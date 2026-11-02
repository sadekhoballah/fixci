import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_ops_state.dart';

class AdminOpsRepository {
  AdminOpsRepository(this._apiClient);

  final AdminApiClient _apiClient;

  Future<List<OnlineCraftsman>> getPresence({String? country}) async {
    final response = await _apiClient.get(
      '/admin/ops/presence${country == null ? '' : '?country=$country'}',
    );
    return (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      final onlineSince = json['onlineSince'] as String?;
      return OnlineCraftsman(
        craftsmanId: json['craftsmanId'] as String,
        fullName: json['fullName'] as String?,
        phone: json['phone'] as String,
        category: json['category'] as String,
        districtName: json['districtName'] as String,
        countryCode: json['countryCode'] as String,
        onlineSince: onlineSince == null ? null : DateTime.parse(onlineSince),
      );
    }).toList();
  }

  Future<OpsStats> getStats(OpsStatsRange range, {String? country}) async {
    final response = await _apiClient.get(
      '/admin/ops/stats?range=${range.apiValue}'
      '${country == null ? '' : '&country=$country'}',
    );
    final directContact = response['directContact'] as Map<String, dynamic>;
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
              countryCode: raw['countryCode'] as String,
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
      byCountry: (response['byCountry'] as List)
          .map(
            (raw) => NamedCount(
              name: (raw as Map<String, dynamic>)['countryCode'] as String,
              count: raw['count'] as int,
            ),
          )
          .toList(),
      directContact: DirectContactStats(
        expired: directContact['expired'] as int,
        contactedRequests: directContact['contactedRequests'] as int,
        whatsappContacts: directContact['whatsappContacts'] as int,
        callContacts: directContact['callContacts'] as int,
      ),
    );
  }
}

final adminOpsRepositoryProvider = Provider<AdminOpsRepository>(
  (ref) => AdminOpsRepository(ref.watch(adminApiClientProvider)),
);
