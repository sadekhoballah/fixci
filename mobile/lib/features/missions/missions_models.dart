import '../../core/models/service_category.dart';

enum MissionStatus {
  draft,
  pendingModeration,
  approvedPublished,
  rejected,
  inProgress,
  completed,
  archived,
}

MissionStatus parseMissionStatus(String wireValue) => switch (wireValue) {
  'draft' => MissionStatus.draft,
  'pending_moderation' => MissionStatus.pendingModeration,
  'approved_published' => MissionStatus.approvedPublished,
  'rejected' => MissionStatus.rejected,
  'in_progress' => MissionStatus.inProgress,
  'completed' => MissionStatus.completed,
  'archived' => MissionStatus.archived,
  _ => MissionStatus.pendingModeration,
};

// When the poster wants the mission done. A coarse weekday + hour
// preference, not a real calendar date — mirrors the rest of the board's
// "no date/map picker" minimalism. UNSPECIFIED is the default; only
// SCHEDULED ever carries a non-null scheduledDayOfWeek/scheduledHour.
enum MissionTimingPreference { unspecified, immediate, scheduled }

MissionTimingPreference parseMissionTimingPreference(String? wireValue) =>
    switch (wireValue) {
      'immediate' => MissionTimingPreference.immediate,
      'scheduled' => MissionTimingPreference.scheduled,
      _ => MissionTimingPreference.unspecified,
    };

String missionTimingPreferenceWireValue(MissionTimingPreference value) =>
    switch (value) {
      MissionTimingPreference.unspecified => 'unspecified',
      MissionTimingPreference.immediate => 'immediate',
      MissionTimingPreference.scheduled => 'scheduled',
    };

// A candidature's own status — separate from MissionStatus (the mission
// itself). 'withdrawn' never actually reaches the client: the backend's
// GET /missions/:id only ever reports the caller's latest non-withdrawn
// application (see MissionsService.getMissionDetail), so a withdrawn-only
// history reads as "never applied" (null) rather than this value — kept
// here anyway so parsing never silently swallows an unexpected value.
enum MissionApplicationStatus { pending, selected, notSelected, withdrawn }

MissionApplicationStatus? parseMissionApplicationStatus(String? wireValue) =>
    switch (wireValue) {
      'pending' => MissionApplicationStatus.pending,
      'selected' => MissionApplicationStatus.selected,
      'not_selected' => MissionApplicationStatus.notSelected,
      'withdrawn' => MissionApplicationStatus.withdrawn,
      _ => null,
    };

ServiceCategory? _parseCategory(String? wireValue) {
  if (wireValue == null) return null;
  for (final category in ServiceCategory.values) {
    if (category.wireValue == wireValue) return category;
  }
  return null;
}

// Board/list row shape — shared by GET /missions and GET /missions/mine.
class MissionSummary {
  const MissionSummary({
    required this.id,
    required this.posterId,
    required this.title,
    required this.description,
    required this.category,
    required this.locationAddress,
    required this.latitude,
    required this.longitude,
    required this.photoStorageKeys,
    required this.status,
    required this.rejectionReason,
    required this.timingPreference,
    required this.scheduledDayOfWeek,
    required this.scheduledHour,
    required this.startingPrice,
    required this.distanceMeters,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String posterId;
  final String title;
  final String description;
  final ServiceCategory? category;
  final String locationAddress;
  // Raw point behind locationAddress — used to reverse-geocode a nicer
  // display address client-side (see ReverseGeocodingService), never shown
  // as-is.
  final double latitude;
  final double longitude;
  final List<String> photoStorageKeys;
  final MissionStatus status;
  final String? rejectionReason;
  final MissionTimingPreference timingPreference;
  // Only non-null together, and only when timingPreference is scheduled.
  // 1 (Monday) .. 7 (Sunday) — matches DateTime.weekday.
  final int? scheduledDayOfWeek;
  final int? scheduledHour;
  // Poster's opening figure — currency-agnostic, see the backend entity.
  final double? startingPrice;
  // Null when the caller didn't supply a position — see
  // MissionsBoardController's best-effort GPS fetch.
  final double? distanceMeters;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MissionSummary.fromJson(Map<String, dynamic> json) =>
      MissionSummary(
        id: json['id'] as String,
        posterId: json['posterId'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: _parseCategory(json['category'] as String?),
        locationAddress: json['locationAddress'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        photoStorageKeys:
            (json['photoStorageKeys'] as List?)?.cast<String>() ?? const [],
        status: parseMissionStatus(json['status'] as String),
        rejectionReason: json['rejectionReason'] as String?,
        timingPreference: parseMissionTimingPreference(
          json['timingPreference'] as String?,
        ),
        scheduledDayOfWeek: (json['scheduledDayOfWeek'] as num?)?.toInt(),
        scheduledHour: (json['scheduledHour'] as num?)?.toInt(),
        startingPrice: json['startingPrice'] == null
            ? null
            : double.parse(json['startingPrice'] as String),
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

// GET /missions/:id shape — everything MissionSummary has, plus the
// caller-relative fields the detail screen needs (own-mission flag,
// candidature status, and the poster's contact info, only ever populated
// server-side when it's actually allowed to be — see the privacy rule on
// MissionsService.getMissionDetail).
class MissionDetail {
  const MissionDetail({
    required this.id,
    required this.posterId,
    required this.title,
    required this.description,
    required this.category,
    required this.locationAddress,
    required this.latitude,
    required this.longitude,
    required this.photoStorageKeys,
    required this.status,
    required this.rejectionReason,
    required this.timingPreference,
    required this.scheduledDayOfWeek,
    required this.scheduledHour,
    required this.startingPrice,
    required this.distanceMeters,
    required this.createdAt,
    required this.updatedAt,
    required this.isOwnMission,
    required this.myApplicationStatus,
    required this.posterFullName,
    required this.posterPhone,
    required this.applicantsCount,
  });

  final String id;
  final String posterId;
  final String title;
  final String description;
  final ServiceCategory? category;
  final String locationAddress;
  final double latitude;
  final double longitude;
  final List<String> photoStorageKeys;
  final MissionStatus status;
  final String? rejectionReason;
  final MissionTimingPreference timingPreference;
  final int? scheduledDayOfWeek;
  final int? scheduledHour;
  final double? startingPrice;
  final double? distanceMeters;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOwnMission;
  final MissionApplicationStatus? myApplicationStatus;
  final String? posterFullName;
  final String? posterPhone;
  // Owner-only — null for a non-owner (see MissionsService.getMissionDetail).
  final int? applicantsCount;

  factory MissionDetail.fromJson(Map<String, dynamic> json) => MissionDetail(
    id: json['id'] as String,
    posterId: json['posterId'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    category: _parseCategory(json['category'] as String?),
    locationAddress: json['locationAddress'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    photoStorageKeys:
        (json['photoStorageKeys'] as List?)?.cast<String>() ?? const [],
    status: parseMissionStatus(json['status'] as String),
    rejectionReason: json['rejectionReason'] as String?,
    timingPreference: parseMissionTimingPreference(
      json['timingPreference'] as String?,
    ),
    scheduledDayOfWeek: (json['scheduledDayOfWeek'] as num?)?.toInt(),
    scheduledHour: (json['scheduledHour'] as num?)?.toInt(),
    startingPrice: json['startingPrice'] == null
        ? null
        : double.parse(json['startingPrice'] as String),
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isOwnMission: json['isOwnMission'] as bool,
    myApplicationStatus: parseMissionApplicationStatus(
      json['myApplicationStatus'] as String?,
    ),
    posterFullName: json['posterFullName'] as String?,
    posterPhone: json['posterPhone'] as String?,
    applicantsCount: (json['applicantsCount'] as num?)?.toInt(),
  );
}

// GET /missions/mine row — either a mission the caller posted or one they
// applied to (roleInMission tells which), including completed/archived
// ones — this is the sole data source for "Mes missions", there's no
// separate archive endpoint.
class MineMissionItem {
  const MineMissionItem({
    required this.id,
    required this.title,
    required this.category,
    required this.locationAddress,
    required this.status,
    required this.updatedAt,
    required this.roleInMission,
    required this.myApplicationStatus,
  });

  final String id;
  final String title;
  final ServiceCategory? category;
  final String locationAddress;
  final MissionStatus status;
  final DateTime updatedAt;
  final String roleInMission; // 'poster' | 'applicant'
  final MissionApplicationStatus? myApplicationStatus;

  factory MineMissionItem.fromJson(Map<String, dynamic> json) =>
      MineMissionItem(
        id: json['id'] as String,
        title: json['title'] as String,
        category: _parseCategory(json['category'] as String?),
        locationAddress: json['locationAddress'] as String,
        status: parseMissionStatus(json['status'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        roleInMission: json['roleInMission'] as String,
        myApplicationStatus: parseMissionApplicationStatus(
          json['myApplicationStatus'] as String?,
        ),
      );
}

// GET /missions/:id/applications row — owner-only.
class MissionApplicant {
  const MissionApplicant({
    required this.applicationId,
    required this.applicantId,
    required this.applicantFullName,
    required this.applicantPhone,
    required this.applicantRole,
    required this.status,
    required this.message,
    required this.distanceMeters,
    required this.averageRating,
    required this.ratingsCount,
    required this.appliedAt,
  });

  final String applicationId;
  final String applicantId;
  final String? applicantFullName;
  final String? applicantPhone;
  final String applicantRole; // 'client' | 'craftsman'
  final MissionApplicationStatus status;
  final String? message;
  final double distanceMeters;
  // Craftsman-only — null for a client applicant (clients aren't rated in
  // this product, see MissionsService.getApplicants).
  final double? averageRating;
  final int? ratingsCount;
  final DateTime appliedAt;

  factory MissionApplicant.fromJson(Map<String, dynamic> json) =>
      MissionApplicant(
        applicationId: json['applicationId'] as String,
        applicantId: json['applicantId'] as String,
        applicantFullName: json['applicantFullName'] as String?,
        applicantPhone: json['applicantPhone'] as String?,
        applicantRole: json['applicantRole'] as String,
        status: parseMissionApplicationStatus(json['status'] as String)!,
        message: json['message'] as String?,
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        averageRating: json['averageRating'] == null
            ? null
            : double.parse(json['averageRating'] as String),
        ratingsCount: (json['ratingsCount'] as num?)?.toInt(),
        appliedAt: DateTime.parse(json['appliedAt'] as String),
      );
}
