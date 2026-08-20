import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_reports_state.dart';

class AdminReportsRepository {
  AdminReportsRepository(this._apiClient);

  final AdminApiClient _apiClient;

  Future<List<AdminPendingReport>> getPendingReports() async {
    final response = await _apiClient.get('/admin/reports');
    return (response['items'] as List).map((raw) {
      final json = raw as Map<String, dynamic>;
      return AdminPendingReport(
        id: json['id'] as String,
        reporterId: json['reporterId'] as String,
        reporterFullName: json['reporterFullName'] as String?,
        reporterPhone: json['reporterPhone'] as String?,
        reportedUserId: json['reportedUserId'] as String,
        reportedUserFullName: json['reportedUserFullName'] as String?,
        reportedUserPhone: json['reportedUserPhone'] as String?,
        reason: json['reason'] as String,
        message: json['message'] as String?,
        contextType: json['contextType'] as String?,
        contextId: json['contextId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    }).toList();
  }

  // action: 'dismiss' | 'warn' | 'deactivate_reported' — see
  // backend/src/admin/dto/resolve-report.dto.ts.
  Future<void> resolveReport(
    String reportId,
    String action, {
    String? note,
  }) => _apiClient.patch('/admin/reports/$reportId/resolve', {
    'action': action,
    if (note != null && note.isNotEmpty) 'note': note,
  });
}

final adminReportsRepositoryProvider = Provider<AdminReportsRepository>(
  (ref) => AdminReportsRepository(ref.watch(adminApiClientProvider)),
);
