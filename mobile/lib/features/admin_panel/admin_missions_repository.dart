import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/service_category.dart';
import 'admin_api_client.dart';
import 'admin_missions_state.dart';

class AdminMissionsRepository {
  AdminMissionsRepository(this._apiClient);

  final AdminApiClient _apiClient;

  Future<List<AdminPendingMission>> getPendingMissions() async {
    final response = await _apiClient.get('/admin/missions/pending');
    return (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      final poster = json['poster'] as Map<String, dynamic>?;
      return AdminPendingMission(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: _parseCategory(json['category'] as String?),
        locationAddress: json['locationAddress'] as String,
        photoStorageKeys:
            (json['photoStorageKeys'] as List?)?.cast<String>() ?? const [],
        posterFullName: poster?['fullName'] as String?,
        posterPhone: poster?['phone'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    }).toList();
  }

  Future<void> approveMission(String missionId) =>
      _apiClient.patch('/admin/missions/$missionId/approve', const {});

  Future<void> rejectMission(String missionId, String? reason) =>
      _apiClient.patch('/admin/missions/$missionId/reject', {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  // The endpoint takes a bare filename, not the "mission-photos/…" prefix
  // stored on the entity — mirrors mission_detail_screen.dart's
  // _MissionPhoto on the client side, against the admin-only endpoint
  // instead (this photo may belong to a mission not yet published, so the
  // public /uploads/mission-photo route can't be reused here).
  Future<Uint8List> getMissionPhotoBytes(String missionId, String storageKey) {
    final filename = storageKey.split('/').last;
    return _apiClient.getBytes('/admin/missions/$missionId/photo/$filename');
  }

  ServiceCategory? _parseCategory(String? wireValue) {
    if (wireValue == null) return null;
    for (final category in ServiceCategory.values) {
      if (category.wireValue == wireValue) return category;
    }
    return null;
  }
}

final adminMissionsRepositoryProvider = Provider<AdminMissionsRepository>(
  (ref) => AdminMissionsRepository(ref.watch(adminApiClientProvider)),
);
