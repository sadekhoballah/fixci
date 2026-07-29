import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_directory_state.dart';

class AdminDirectoryRepository {
  AdminDirectoryRepository(this._apiClient);

  final AdminApiClient _apiClient;

  Future<List<DirectoryEntry>> getClients({String? search}) async {
    final query = (search != null && search.isNotEmpty)
        ? '?search=${Uri.encodeQueryComponent(search)}'
        : '';
    final response = await _apiClient.get('/admin/directory/clients$query');
    return _parseItems(response, includeCategory: false);
  }

  Future<List<DirectoryEntry>> getCraftsmen({
    String? search,
    String? category,
  }) async {
    final params = <String>[
      if (search != null && search.isNotEmpty)
        'search=${Uri.encodeQueryComponent(search)}',
      if (category != null) 'category=${Uri.encodeQueryComponent(category)}',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final response = await _apiClient.get(
      '/admin/directory/craftsmen$query',
    );
    return _parseItems(response, includeCategory: true);
  }

  List<DirectoryEntry> _parseItems(
    Map<String, dynamic> response, {
    required bool includeCategory,
  }) {
    return (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      return DirectoryEntry(
        userId: json['userId'] as String,
        fullName: json['fullName'] as String?,
        phone: json['phone'] as String,
        districtName: json['districtName'] as String,
        isOnline: json['isOnline'] as bool,
        serviceCategory: includeCategory
            ? json['serviceCategory'] as String?
            : null,
      );
    }).toList();
  }
}

final adminDirectoryRepositoryProvider = Provider<AdminDirectoryRepository>(
  (ref) => AdminDirectoryRepository(ref.watch(adminApiClientProvider)),
);
