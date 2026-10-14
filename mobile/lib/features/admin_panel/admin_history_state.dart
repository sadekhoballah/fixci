import 'admin_ops_state.dart';

class HistoryUser {
  const HistoryUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.deleted,
  });

  final String id;
  final String? fullName;
  final String? phone;
  // Self-deleted account: the row survives but name/phone are wiped.
  final bool deleted;

  String get displayName {
    if (deleted) return 'Compte supprimé';
    return fullName ?? phone ?? '—';
  }
}

class MissionHistoryItem {
  const MissionHistoryItem({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.locationAddress,
    required this.startingPrice,
    required this.rejectionReason,
    required this.poster,
    required this.posterRole,
    required this.performer,
    required this.applicationsCount,
    required this.createdAt,
    required this.publishedAt,
    required this.selectedAt,
    required this.completedAt,
    required this.archivedAt,
    required this.endedAt,
  });

  final String id;
  final String title;
  final String? category;
  final String status;
  final String locationAddress;
  final String? startingPrice;
  final String? rejectionReason;
  final HistoryUser poster;
  final String posterRole;
  final HistoryUser? performer;
  final int applicationsCount;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final DateTime? selectedAt;
  final DateTime? completedAt;
  final DateTime? archivedAt;
  final DateTime endedAt;
}

class RequestHistoryItem {
  const RequestHistoryItem({
    required this.id,
    required this.category,
    required this.status,
    required this.client,
    required this.craftsman,
    required this.createdAt,
    required this.assignedAt,
    required this.startedAt,
    required this.completedAt,
    required this.cancelledAt,
    required this.endedAt,
    required this.ratingStars,
  });

  final String id;
  final String category;
  final String status;
  final HistoryUser client;
  final HistoryUser? craftsman;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? endedAt;
  final int? ratingStars;
}

class HistoryPage<T> {
  const HistoryPage({
    required this.items,
    required this.total,
    required this.byStatus,
  });

  final List<T> items;
  final int total;
  // Breakdown under the current filters, ignoring the status filter itself.
  final List<StatusCount> byStatus;
}

// Shared by both history tabs: same paging/filter/loading shape, only the
// item type and the extra search fields differ.
class AdminHistoryState<T> {
  const AdminHistoryState({
    this.items = const [],
    this.total = 0,
    this.byStatus = const [],
    this.status,
    this.date,
    this.search = '',
    this.client = '',
    this.artisan = '',
    this.isLoading = true,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final List<T> items;
  final int total;
  final List<StatusCount> byStatus;
  final String? status;
  final DateTime? date;
  // Missions tab: free text (title / poster / performer).
  final String search;
  // Requests tab: client and artisan name-or-phone.
  final String client;
  final String artisan;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get hasMore => items.length < total;

  AdminHistoryState<T> copyWith({
    List<T>? items,
    int? total,
    List<StatusCount>? byStatus,
    String? status,
    bool clearStatus = false,
    DateTime? date,
    bool clearDate = false,
    String? search,
    String? client,
    String? artisan,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminHistoryState<T>(
      items: items ?? this.items,
      total: total ?? this.total,
      byStatus: byStatus ?? this.byStatus,
      status: clearStatus ? null : (status ?? this.status),
      date: clearDate ? null : (date ?? this.date),
      search: search ?? this.search,
      client: client ?? this.client,
      artisan: artisan ?? this.artisan,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
