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

  // Force-cancels any mission the account is currently a party to. Must be
  // called before deleteAccount when that throws a 409 ("mission en
  // cours") — see AdminDirectoryController.deleteAccount.
  Future<void> cancelActiveMissions(String userId) => _apiClient.post(
    '/admin/directory/users/$userId/cancel-active-missions',
    const {},
  );

  // Irreversible: anonymizes the account so its phone number is freed for
  // re-registration. Throws AdminApiException with statusCode 409 if the
  // account still has a mission in progress.
  Future<void> deleteAccount(String userId, String? reason) => _apiClient
      .delete(
        '/admin/directory/users/$userId',
        (reason != null && reason.isNotEmpty) ? {'reason': reason} : null,
      );

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
