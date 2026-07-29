import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_broadcast_state.dart';

class AdminBroadcastRepository {
  AdminBroadcastRepository(this._apiClient);

  final AdminApiClient _apiClient;

  Future<List<BroadcastHistoryEntry>> getHistory() async {
    final response = await _apiClient.get('/admin/broadcast');
    return (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      final district = json['targetDistrict'] as Map<String, dynamic>?;
      return BroadcastHistoryEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        targetRole: json['targetRole'] as String?,
        targetServiceCategory: json['targetServiceCategory'] as String?,
        targetDistrictName: district?['name'] as String?,
        waitlistOnly: json['waitlistOnly'] as bool,
        recipientCount: json['recipientCount'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    }).toList();
  }

  Future<BroadcastSendResult> send({
    required String title,
    required String body,
    String? role,
    String? serviceCategory,
    String? districtId,
    bool waitlistOnly = false,
  }) async {
    final response = await _apiClient.post('/admin/broadcast', {
      'title': title,
      'body': body,
      'role': ?role,
      'serviceCategory': ?serviceCategory,
      'districtId': ?districtId,
      'waitlistOnly': waitlistOnly,
    });
    return BroadcastSendResult(
      recipientCount: response['recipientCount'] as int,
      successCount: response['successCount'] as int,
      failureCount: response['failureCount'] as int,
    );
  }
}

final adminBroadcastRepositoryProvider = Provider<AdminBroadcastRepository>(
  (ref) => AdminBroadcastRepository(ref.watch(adminApiClientProvider)),
);
