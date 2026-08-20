import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_auth_controller.dart';
import 'admin_reports_repository.dart';
import 'admin_reports_state.dart';

class AdminReportsController extends Notifier<AdminReportsState> {
  @override
  AdminReportsState build() {
    Future.microtask(refresh);
    return const AdminReportsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final entries = await ref
          .read(adminReportsRepositoryProvider)
          .getPendingReports();
      state = state.copyWith(isLoading: false, entries: entries);
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les signalements.',
      );
    }
  }

  Future<void> resolve(String reportId, String action, {String? note}) async {
    if (state.processingReportIds.contains(reportId)) return;
    state = state.copyWith(
      processingReportIds: {...state.processingReportIds, reportId},
      clearError: true,
    );
    try {
      await ref
          .read(adminReportsRepositoryProvider)
          .resolveReport(reportId, action, note: note);
      state = state.copyWith(
        entries: state.entries.where((e) => e.id != reportId).toList(),
        processingReportIds: state.processingReportIds
            .where((id) => id != reportId)
            .toSet(),
      );
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(
        errorMessage: e.message,
        processingReportIds: state.processingReportIds
            .where((id) => id != reportId)
            .toSet(),
      );
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Une erreur est survenue.',
        processingReportIds: state.processingReportIds
            .where((id) => id != reportId)
            .toSet(),
      );
    }
  }

  Future<void> _handlePossibleAuthFailure(AdminApiException e) async {
    if (e.statusCode == 401) {
      await ref.read(adminAuthControllerProvider.notifier).logout();
    }
  }
}

final adminReportsControllerProvider =
    NotifierProvider<AdminReportsController, AdminReportsState>(
      AdminReportsController.new,
    );
