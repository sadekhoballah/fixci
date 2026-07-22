import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/network/api_client.dart';
import 'craftsman_home_repository.dart';
import 'craftsman_home_state.dart';

const _statsRefreshInterval = Duration(seconds: 30);

class CraftsmanHomeController extends Notifier<CraftsmanHomeState> {
  Timer? _statsRefreshTimer;

  @override
  CraftsmanHomeState build() {
    Future.microtask(_load);
    _statsRefreshTimer = Timer.periodic(
      _statsRefreshInterval,
      (_) => refreshStats(),
    );
    ref.onDispose(() => _statsRefreshTimer?.cancel());
    return const CraftsmanHomeState();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(craftsmanHomeRepositoryProvider);
      final me = await repository.getMe();
      final stats = await repository.getStats();
      state = state.copyWith(
        isLoading: false,
        tier: me.tier,
        daysRemaining: me.daysRemaining,
        isAvailable: me.isAvailable,
        averageRating: me.averageRating,
        ratingsCount: me.ratingsCount,
        stats: stats,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger votre tableau de bord.',
      );
    }
  }

  Future<void> refresh() => _load();

  // Keeps the live job/stats counters from going stale between full
  // dashboard reloads — see _statsRefreshTimer above.
  Future<void> refreshStats() async {
    try {
      final stats = await ref.read(craftsmanHomeRepositoryProvider).getStats();
      state = state.copyWith(stats: stats);
    } catch (_) {
      // Silent — the stats bar just keeps showing the last known numbers.
    }
  }

  Future<void> toggleAvailability(bool wantsAvailable) async {
    if (state.isTogglingAvailability) return;

    state = state.copyWith(isTogglingAvailability: true, clearError: true);
    try {
      double? latitude;
      double? longitude;
      if (wantsAvailable) {
        final position = await _getCurrentPosition();
        if (position == null) {
          state = state.copyWith(
            isTogglingAvailability: false,
            errorMessage:
                "Activez la localisation pour passer en service.",
          );
          return;
        }
        latitude = position.latitude;
        longitude = position.longitude;
      }

      final isAvailable = await ref
          .read(craftsmanHomeRepositoryProvider)
          .setAvailability(
            wantsAvailable,
            latitude: latitude,
            longitude: longitude,
          );
      state = state.copyWith(
        isTogglingAvailability: false,
        isAvailable: isAvailable,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isTogglingAvailability: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isTogglingAvailability: false,
        errorMessage: 'Impossible de mettre à jour votre disponibilité.',
      );
    }
  }

  Future<Position?> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}

final craftsmanHomeControllerProvider =
    NotifierProvider<CraftsmanHomeController, CraftsmanHomeState>(
      CraftsmanHomeController.new,
    );
