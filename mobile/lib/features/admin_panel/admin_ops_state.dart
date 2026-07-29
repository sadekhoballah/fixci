class OnlineCraftsman {
  const OnlineCraftsman({
    required this.craftsmanId,
    required this.fullName,
    required this.phone,
    required this.category,
    required this.districtName,
    required this.onlineSince,
  });

  final String craftsmanId;
  final String? fullName;
  final String phone;
  final String category;
  final String districtName;
  final DateTime? onlineSince;
}

class StatusCount {
  const StatusCount({required this.status, required this.count});

  final String status;
  final int count;
}

class NamedCount {
  const NamedCount({required this.name, required this.count});

  final String name;
  final int count;
}

enum OpsStatsRange { today, week, all }

extension OpsStatsRangeApi on OpsStatsRange {
  String get apiValue => switch (this) {
    OpsStatsRange.today => 'today',
    OpsStatsRange.week => 'week',
    OpsStatsRange.all => 'all',
  };

  String get label => switch (this) {
    OpsStatsRange.today => "Aujourd'hui",
    OpsStatsRange.week => '7 jours',
    OpsStatsRange.all => 'Tout',
  };
}

class OpsStats {
  const OpsStats({
    required this.byStatus,
    required this.byDistrict,
    required this.byCategory,
  });

  final List<StatusCount> byStatus;
  final List<NamedCount> byDistrict;
  final List<NamedCount> byCategory;
}

class AdminOpsState {
  const AdminOpsState({
    this.range = OpsStatsRange.today,
    this.online = const [],
    this.stats,
    this.isLoading = true,
    this.errorMessage,
  });

  final OpsStatsRange range;
  final List<OnlineCraftsman> online;
  final OpsStats? stats;
  final bool isLoading;
  final String? errorMessage;

  AdminOpsState copyWith({
    OpsStatsRange? range,
    List<OnlineCraftsman>? online,
    OpsStats? stats,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminOpsState(
      range: range ?? this.range,
      online: online ?? this.online,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
