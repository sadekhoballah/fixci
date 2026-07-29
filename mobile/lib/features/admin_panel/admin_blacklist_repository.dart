import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_blacklist_state.dart';

class AdminBlacklistRepository {
  AdminBlacklistRepository(this._apiClient);

  final AdminApiClient _apiClient;

  Future<List<BlacklistedPhone>> getEntries() async {
    final response = await _apiClient.get('/admin/blacklist');
    return (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      return BlacklistedPhone(
        id: json['id'] as String,
        phone: json['phone'] as String,
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    }).toList();
  }

  Future<void> addEntry(String phone, String? reason) =>
      _apiClient.post('/admin/blacklist', {
        'phone': phone,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<void> removeEntry(String id) =>
      _apiClient.delete('/admin/blacklist/$id');
}

final adminBlacklistRepositoryProvider = Provider<AdminBlacklistRepository>(
  (ref) => AdminBlacklistRepository(ref.watch(adminApiClientProvider)),
);
