import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_api_client.dart';
import 'admin_auth_controller.dart';
import 'admin_ops_repository.dart';
import 'admin_ops_state.dart';

const _refreshInterval = Duration(seconds: 10);

class AdminOpsController extends Notifier<AdminOpsState> {
  Timer? _refreshTimer;

  @override
  AdminOpsState build() {
    Future.microtask(refresh);
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refresh());
    ref.onDispose(() => _refreshTimer?.cancel());
    return const AdminOpsState();
  }

  Future<void> setRange(OpsStatsRange range) async {
    if (range == state.range) return;
    state = state.copyWith(range: range);
    await refresh();
  }

  // Silent on the periodic tick (no loading spinner flicker), but still
  // surfaces errors — a background poll failing shouldn't look like success.
  Future<void> refresh() async {
    final isFirstLoad = state.stats == null;
    if (isFirstLoad) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final repository = ref.read(adminOpsRepositoryProvider);
      final results = await Future.wait([
        repository.getPresence(),
        repository.getStats(state.range),
      ]);
      state = state.copyWith(
        isLoading: false,
        clearError: true,
        online: results[0] as List<OnlineCraftsman>,
        stats: results[1] as OpsStats,
      );
    } on AdminApiException catch (e) {
      await _handlePossibleAuthFailure(e);
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les données.',
      );
    }
  }

  Future<void> _handlePossibleAuthFailure(AdminApiException e) async {
    if (e.statusCode == 401) {
      await ref.read(adminAuthControllerProvider.notifier).logout();
    }
  }
}

final adminOpsControllerProvider =
    NotifierProvider<AdminOpsController, AdminOpsState>(AdminOpsController.new);
