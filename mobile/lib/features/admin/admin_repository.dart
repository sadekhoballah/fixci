import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';
import 'admin_state.dart';

class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PendingVerification>> getPendingVerifications() async {
    final response = await _apiClient.get('/admin/verifications');
    return (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      final role = json['role'] == 'client'
          ? VerificationRole.client
          : VerificationRole.craftsman;
      return PendingVerification(
        userId: json['userId'] as String,
        role: role,
        fullName: json['fullName'] as String?,
        phone: json['phone'] as String,
        serviceCategory: json['serviceCategory'] == null
            ? null
            : _parseCategory(json['serviceCategory'] as String),
        experienceDetails: json['experienceDetails'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    }).toList();
  }

  Future<void> verifyCraftsman(String userId) =>
      _apiClient.patch('/admin/craftsmen/$userId/verify', const {});

  Future<void> deactivateCraftsman(String userId) =>
      _apiClient.patch('/admin/craftsmen/$userId/deactivate', const {});

  Future<void> verifyClient(String userId) =>
      _apiClient.patch('/admin/clients/$userId/verify', const {});

  Future<void> deactivateClient(String userId) =>
      _apiClient.patch('/admin/clients/$userId/deactivate', const {});

  Future<Uint8List> getIdCardBytes(String userId, VerificationRole role) =>
      _apiClient.getBytes(
        role == VerificationRole.client
            ? '/admin/clients/$userId/id-card'
            : '/admin/craftsmen/$userId/id-card',
      );

  ServiceCategory _parseCategory(String wireValue) => ServiceCategory.values
      .firstWhere((c) => c.wireValue == wireValue, orElse: () => ServiceCategory.plumber);
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);
