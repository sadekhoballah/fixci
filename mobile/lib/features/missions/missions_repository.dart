import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/media/id_card_picker.dart';
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';
import 'missions_models.dart';

class MissionsRepository {
  MissionsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CreatedMission> createMission({
    required String title,
    required String description,
    required String locationAddress,
    required double latitude,
    required double longitude,
    ServiceCategory? category,
    List<String> photoStorageKeys = const [],
    MissionTimingPreference timingPreference =
        MissionTimingPreference.unspecified,
    int? scheduledDayOfWeek,
    int? scheduledHour,
    double? startingPrice,
  }) async {
    final response = await _apiClient.post('/missions', {
      'title': title,
      'description': description,
      'locationAddress': locationAddress,
      'latitude': latitude,
      'longitude': longitude,
      if (category != null) 'category': category.wireValue,
      if (photoStorageKeys.isNotEmpty) 'photoStorageKeys': photoStorageKeys,
      'timingPreference': missionTimingPreferenceWireValue(timingPreference),
      if (scheduledDayOfWeek != null) 'scheduledDayOfWeek': scheduledDayOfWeek,
      if (scheduledHour != null) 'scheduledHour': scheduledHour,
      if (startingPrice != null) 'startingPrice': startingPrice,
    });
    return CreatedMission(
      id: response['id'] as String,
      status: parseMissionStatus(response['status'] as String),
    );
  }

  Future<MissionBoardPage> browseMissions({
    required int limit,
    required int offset,
    double? latitude,
    double? longitude,
  }) async {
    final query = {
      'limit': '$limit',
      'offset': '$offset',
      if (latitude != null) 'latitude': '$latitude',
      if (longitude != null) 'longitude': '$longitude',
    };
    final response = await _apiClient.get(
      '/missions?${Uri(queryParameters: query).query}',
    );
    final items = (response['items'] as List)
        .map((raw) => MissionSummary.fromJson(raw as Map<String, dynamic>))
        .toList();
    return MissionBoardPage(
      items: items,
      hasMore: response['hasMore'] as bool,
    );
  }

  Future<MissionDetail> getMissionDetail(
    String missionId, {
    double? latitude,
    double? longitude,
  }) async {
    final query = {
      if (latitude != null) 'latitude': '$latitude',
      if (longitude != null) 'longitude': '$longitude',
    };
    final suffix = query.isEmpty
        ? ''
        : '?${Uri(queryParameters: query).query}';
    final response = await _apiClient.get('/missions/$missionId$suffix');
    return MissionDetail.fromJson(response);
  }

  Future<MineMissionsPage> getMyMissions({
    required int limit,
    required int offset,
  }) async {
    final response = await _apiClient.get(
      '/missions/mine?limit=$limit&offset=$offset',
    );
    final items = (response['items'] as List)
        .map((raw) => MineMissionItem.fromJson(raw as Map<String, dynamic>))
        .toList();
    return MineMissionsPage(items: items, hasMore: response['hasMore'] as bool);
  }

  Future<List<MissionApplicant>> getApplicants(String missionId) async {
    final response = await _apiClient.get('/missions/$missionId/applications');
    return (response['items'] as List)
        .map((raw) => MissionApplicant.fromJson(raw as Map<String, dynamic>))
        .toList();
  }

  Future<void> selectApplicant(String missionId, String applicationId) {
    return _apiClient.patch(
      '/missions/$missionId/applications/$applicationId/select',
      const {},
    );
  }

  Future<void> withdrawMission(String missionId) {
    return _apiClient.patch('/missions/$missionId/withdraw', const {});
  }

  Future<void> completeMission(String missionId) {
    return _apiClient.patch('/missions/$missionId/complete', const {});
  }

  Future<void> applyToMission(
    String missionId, {
    required double latitude,
    required double longitude,
    String? message,
  }) {
    return _apiClient.post('/missions/$missionId/applications', {
      'latitude': latitude,
      'longitude': longitude,
      if (message != null && message.isNotEmpty) 'message': message,
    });
  }

  Future<String> uploadMissionPhoto(PickedImage image) async {
    final response = await _apiClient.postMultipart(
      '/uploads/mission-photo',
      'file',
      image.bytes,
      image.filename,
      contentTypeHeader: image.mimeType,
    );
    return response['storageKey'] as String;
  }
}

class CreatedMission {
  const CreatedMission({required this.id, required this.status});

  final String id;
  final MissionStatus status;
}

class MissionBoardPage {
  const MissionBoardPage({required this.items, required this.hasMore});

  final List<MissionSummary> items;
  final bool hasMore;
}

class MineMissionsPage {
  const MineMissionsPage({required this.items, required this.hasMore});

  final List<MineMissionItem> items;
  final bool hasMore;
}

final missionsRepositoryProvider = Provider<MissionsRepository>(
  (ref) => MissionsRepository(ref.watch(apiClientProvider)),
);
