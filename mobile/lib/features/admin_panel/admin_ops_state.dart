class OnlineCraftsman {
  const OnlineCraftsman({
    required this.craftsmanId,
    required this.fullName,
    required this.phone,
    required this.category,
    required this.districtName,
    required this.countryCode,
    required this.onlineSince,
  });

  final String craftsmanId;
  final String? fullName;
  final String phone;
  final String category;
  final String districtName;
  final String countryCode;
  final DateTime? onlineSince;
}

class StatusCount {
  const StatusCount({required this.status, required this.count});

  final String status;
  final int count;
}

class NamedCount {
  const NamedCount({required this.name, required this.count, this.countryCode});

  final String name;
  final int count;
  // Set for district rows, so they can carry their country's flag.
  final String? countryCode;
}

// After the 75 s window closed with nobody accepting: how many of those
// requests ended with the client reaching a craftsman from the "contact
// directly" list, and through which channel.
class DirectContactStats {
  const DirectContactStats({
    required this.expired,
    required this.contactedRequests,
    required this.whatsappContacts,
    required this.callContacts,
  });

  final int expired;
  final int contactedRequests;
  final int whatsappContacts;
  final int callContacts;
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
    required this.byCountry,
    required this.directContact,
  });

  final List<StatusCount> byStatus;
  final List<NamedCount> byDistrict;
  final List<NamedCount> byCategory;
  // name = country code.
  final List<NamedCount> byCountry;
  final DirectContactStats directContact;
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
    bool clearStats = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminOpsState(
      range: range ?? this.range,
      online: online ?? this.online,
      stats: clearStats ? null : (stats ?? this.stats),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
