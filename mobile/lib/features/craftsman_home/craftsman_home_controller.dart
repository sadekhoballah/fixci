import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/network/api_client.dart';
import 'craftsman_home_repository.dart';
import 'craftsman_home_state.dart';
import 'live_requests_controller.dart';

const _statsRefreshInterval = Duration(seconds: 30);
const _locationPingInterval = Duration(seconds: 20);

class CraftsmanHomeController extends Notifier<CraftsmanHomeState> {
  Timer? _statsRefreshTimer;
  Timer? _locationPingTimer;

  @override
  CraftsmanHomeState build() {
    Future.microtask(() async {
      await refreshLocationStatus();
      await _load();
    });
    _statsRefreshTimer = Timer.periodic(
      _statsRefreshInterval,
      (_) => refreshStats(),
    );
    ref.onDispose(() {
      _statsRefreshTimer?.cancel();
      _locationPingTimer?.cancel();
    });
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
        fullName: me.fullName,
        tier: me.tier,
        daysRemaining: me.daysRemaining,
        isAvailable: me.isAvailable,
        averageRating: me.averageRating,
        ratingsCount: me.ratingsCount,
        stats: stats,
        serviceCategory: me.serviceCategory,
      );
      if (me.isAvailable) {
        _startLiveRequests();
      }
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

  // Checked on load and whenever the app resumes (a user who left to grant
  // permission/enable GPS in system Settings should see the card update the
  // moment they come back, not just on the next manual refresh).
  Future<void> refreshLocationStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    state = state.copyWith(
      locationServiceEnabled: serviceEnabled,
      locationPermission: permission,
    );
  }

  // The GPS status card's button. Follows the official, store-compliant
  // sequence: request the app permission first if that's the blocker, then
  // deep-link to the relevant system settings screen — never anything that
  // tries to flip the OS location toggle programmatically, which neither
  // platform allows a normal app to do.
  Future<void> requestLocationAccess() async {
    var permission = state.locationPermission;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      state = state.copyWith(locationPermission: permission);
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    if (!state.locationServiceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    await refreshLocationStatus();
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
            errorMessage: "Activez la localisation pour passer en service.",
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

      if (isAvailable) {
        _startLiveRequests(latitude: latitude, longitude: longitude);
      } else {
        _stopLiveRequests();
      }
    } on ApiException catch (e) {
      state = state.copyWith(
        isTogglingAvailability: false,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        isTogglingAvailability: false,
        errorMessage: 'Impossible de mettre à jour votre disponibilité.',
      );
    }
  }

  void handleAppResumed() {
    unawaited(refreshLocationStatus());
    final category = state.serviceCategory;
    if (state.isAvailable && category != null) {
      unawaited(() async {
        final position = await _getCurrentPosition();
        if (position == null) return;
        ref
            .read(liveRequestsControllerProvider.notifier)
            .handleAppResumed(
              category: category,
              latitude: position.latitude,
              longitude: position.longitude,
            );
      }());
    }
  }

  void _startLiveRequests({double? latitude, double? longitude}) {
    final category = state.serviceCategory;
    if (category == null) return;
    final controller = ref.read(liveRequestsControllerProvider.notifier);

    Future<void> start(double lat, double lng) async {
      controller.startListening(category: category, latitude: lat, longitude: lng);
    }

    if (latitude != null && longitude != null) {
      unawaited(start(latitude, longitude));
    } else {
      unawaited(() async {
        final position = await _getCurrentPosition();
        if (position != null) {
          await start(position.latitude, position.longitude);
        }
      }());
    }

    _locationPingTimer?.cancel();
    _locationPingTimer = Timer.periodic(_locationPingInterval, (_) async {
      final position = await _getCurrentPosition();
      if (position != null) {
        controller.updateLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    });
  }

  void _stopLiveRequests() {
    _locationPingTimer?.cancel();
    ref.read(liveRequestsControllerProvider.notifier).stopListening();
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
