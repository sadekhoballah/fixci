import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/service_category.dart';
import 'admin_api_client.dart';
import 'admin_kyc_state.dart';

class AdminKycRepository {
  AdminKycRepository(this._apiClient);

  final AdminApiClient _apiClient;

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
        licenseVerified: json['licenseVerified'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        idAutoCheck: IdAutoCheck.fromJson(
          json['idAutoCheck'] as Map<String, dynamic>?,
        ),
        licenseAutoCheck: IdAutoCheck.fromJson(
          json['licenseAutoCheck'] as Map<String, dynamic>?,
        ),
      );
    }).toList();
  }

  Future<void> verifyCraftsman(String userId) =>
      _apiClient.patch('/admin/craftsmen/$userId/verify', const {});

  Future<void> deactivateCraftsman(String userId, String? reason) =>
      _apiClient.patch('/admin/craftsmen/$userId/deactivate', {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<void> verifyClient(String userId) =>
      _apiClient.patch('/admin/clients/$userId/verify', const {});

  Future<void> deactivateClient(String userId, String? reason) =>
      _apiClient.patch('/admin/clients/$userId/deactivate', {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<Uint8List> getIdCardBytes(String userId, VerificationRole role) =>
      _apiClient.getBytes(
        role == VerificationRole.client
            ? '/admin/clients/$userId/id-card'
            : '/admin/craftsmen/$userId/id-card',
      );

  // Craftsman-only — taxi/camion's second KYC document.
  Future<Uint8List> getLicenseBytes(String userId) =>
      _apiClient.getBytes('/admin/craftsmen/$userId/license');

  ServiceCategory _parseCategory(String wireValue) => ServiceCategory.values
      .firstWhere(
        (c) => c.wireValue == wireValue,
        orElse: () => ServiceCategory.plumber,
      );
}

final adminKycRepositoryProvider = Provider<AdminKycRepository>(
  (ref) => AdminKycRepository(ref.watch(adminApiClientProvider)),
);
