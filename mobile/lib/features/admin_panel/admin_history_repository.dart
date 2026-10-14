import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_history_state.dart';
import 'admin_ops_state.dart';

// Read-only: both endpoints are plain GETs under /admin/ops.
class AdminHistoryRepository {
  AdminHistoryRepository(this._apiClient);

  final AdminApiClient _apiClient;

  Future<HistoryPage<MissionHistoryItem>> getMissionHistory({
    String? status,
    DateTime? date,
    String search = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      _path('/admin/ops/missions-history', {
        'status': status,
        'date': _dateParam(date),
        'search': search.trim(),
        'limit': '$limit',
        'offset': '$offset',
      }),
    );
    return _parsePage(response, (json) {
      final performer = json['performer'] as Map<String, dynamic>?;
      final poster = json['poster'] as Map<String, dynamic>;
      return MissionHistoryItem(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String?,
        status: json['status'] as String,
        locationAddress: json['locationAddress'] as String,
        startingPrice: json['startingPrice'] as String?,
        rejectionReason: json['rejectionReason'] as String?,
        poster: _parseUser(poster),
        posterRole: poster['role'] as String,
        performer: performer == null ? null : _parseUser(performer),
        applicationsCount: json['applicationsCount'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        publishedAt: _parseDate(json['publishedAt']),
        selectedAt: _parseDate(json['selectedAt']),
        completedAt: _parseDate(json['completedAt']),
        archivedAt: _parseDate(json['archivedAt']),
        endedAt: DateTime.parse(json['endedAt'] as String),
      );
    });
  }

  Future<HistoryPage<RequestHistoryItem>> getRequestHistory({
    String? status,
    DateTime? date,
    String client = '',
    String artisan = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      _path('/admin/ops/requests', {
        'status': status,
        'date': _dateParam(date),
        'client': client.trim(),
        'artisan': artisan.trim(),
        'limit': '$limit',
        'offset': '$offset',
      }),
    );
    return _parsePage(response, (json) {
      final craftsman = json['craftsman'] as Map<String, dynamic>?;
      return RequestHistoryItem(
        id: json['id'] as String,
        category: json['category'] as String,
        status: json['status'] as String,
        client: _parseUser(json['client'] as Map<String, dynamic>),
        craftsman: craftsman == null ? null : _parseUser(craftsman),
        createdAt: DateTime.parse(json['createdAt'] as String),
        assignedAt: _parseDate(json['assignedAt']),
        startedAt: _parseDate(json['startedAt']),
        completedAt: _parseDate(json['completedAt']),
        cancelledAt: _parseDate(json['cancelledAt']),
        endedAt: _parseDate(json['endedAt']),
        ratingStars: json['ratingStars'] as int?,
      );
    });
  }

  String _path(String base, Map<String, String?> params) {
    final query = params.entries
        .where((e) => e.value != null && e.value!.isNotEmpty)
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value!)}')
        .join('&');
    return query.isEmpty ? base : '$base?$query';
  }

  // The backend filters on the UTC calendar day (Abidjan is UTC+0); the
  // picker hands back a local midnight, so only its Y/M/D are meaningful.
  String? _dateParam(DateTime? date) {
    if (date == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  HistoryPage<T> _parsePage<T>(
    Map<String, dynamic> response,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    return HistoryPage(
      items: (response['items'] as List)
          .map((raw) => parseItem(raw as Map<String, dynamic>))
          .toList(),
      total: response['total'] as int,
      byStatus: (response['byStatus'] as List)
          .map(
            (raw) => StatusCount(
              status: (raw as Map<String, dynamic>)['status'] as String,
              count: raw['count'] as int,
            ),
          )
          .toList(),
    );
  }

  HistoryUser _parseUser(Map<String, dynamic> json) => HistoryUser(
    id: json['id'] as String,
    fullName: json['fullName'] as String?,
    phone: json['phone'] as String?,
    deleted: json['deleted'] as bool? ?? false,
  );

  DateTime? _parseDate(Object? raw) =>
      raw == null ? null : DateTime.parse(raw as String);
}

final adminHistoryRepositoryProvider = Provider<AdminHistoryRepository>(
  (ref) => AdminHistoryRepository(ref.watch(adminApiClientProvider)),
);
