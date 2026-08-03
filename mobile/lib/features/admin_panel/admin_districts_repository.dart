import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_districts_state.dart';

class AdminDistrictsRepository {
  AdminDistrictsRepository(this._apiClient);

  final AdminApiClient _apiClient;

  Future<List<DistrictWithCounts>> getDistricts() async {
    final response = await _apiClient.get('/admin/districts');
    return (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      return DistrictWithCounts(
        id: json['id'] as String,
        name: json['name'] as String,
        countryCode: json['countryCode'] as String,
        isArtisanRegistrationActive:
            json['isArtisanRegistrationActive'] as bool,
        isClientOrderingActive: json['isClientOrderingActive'] as bool,
        artisansCount: json['artisansCount'] as int,
        clientsCount: json['clientsCount'] as int,
      );
    }).toList();
  }

  Future<void> createDistrict(String name, String countryCode) =>
      _apiClient.post('/admin/districts', {
        'name': name,
        'countryCode': countryCode,
      });

  Future<void> updateToggles(
    String id, {
    bool? isArtisanRegistrationActive,
    bool? isClientOrderingActive,
  }) => _apiClient.patch('/admin/districts/$id', {
    'isArtisanRegistrationActive': ?isArtisanRegistrationActive,
    'isClientOrderingActive': ?isClientOrderingActive,
  });
}

final adminDistrictsRepositoryProvider = Provider<AdminDistrictsRepository>(
  (ref) => AdminDistrictsRepository(ref.watch(adminApiClientProvider)),
);
