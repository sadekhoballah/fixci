import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/location/location_service.dart' as location_service;
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
      // Being reachable for new jobs shouldn't require a separate manual
      // step on top of granting location — attempt to go online from GPS
      // alone on every load. The toggle still exists purely as an explicit
      // opt-out (toggleAvailability(false)) for a craftsman who wants to
      // stop receiving jobs without closing the app.
      unawaited(_goOnlineFromGps());
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

      if (isAvailable && latitude != null && longitude != null) {
        _startLiveRequests(latitude: latitude, longitude: longitude);
      } else if (!isAvailable) {
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

  // Reachability for new jobs only needs a GPS fix, not a separate manual
  // step — called on every load so a craftsman who simply opens the app
  // with location already granted starts receiving requests immediately.
  // The toggle above remains as an explicit opt-out for someone who wants
  // to stay logged in without being matched.
  Future<void> _goOnlineFromGps() async {
    final position = await _getCurrentPosition();
    if (position == null) {
      if (!state.isAvailable) {
        state = state.copyWith(
          errorMessage: "Activez la localisation pour recevoir des demandes.",
        );
      }
      return;
    }

    _startLiveRequests(latitude: position.latitude, longitude: position.longitude);

    if (!state.isAvailable) {
      try {
        final isAvailable = await ref
            .read(craftsmanHomeRepositoryProvider)
            .setAvailability(
              true,
              latitude: position.latitude,
              longitude: position.longitude,
            );
        state = state.copyWith(isAvailable: isAvailable);
      } catch (_) {
        // Presence is already live over the socket regardless — this PATCH
        // only keeps the isAvailable flag in sync for display elsewhere, so
        // a failure here doesn't stop the craftsman from receiving jobs.
      }
    }
  }

  void handleAppResumed() {
    unawaited(refreshLocationStatus());
    final category = state.serviceCategory;
    if (category == null) return;
    if (state.isAvailable) {
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
    } else {
      // Covers granting location permission while backgrounded, then
      // returning — without this, going online would otherwise wait for
      // the next full app restart.
      unawaited(_goOnlineFromGps());
    }
  }

  void _startLiveRequests({required double latitude, required double longitude}) {
    final category = state.serviceCategory;
    if (category == null) return;
    ref
        .read(liveRequestsControllerProvider.notifier)
        .startListening(category: category, latitude: latitude, longitude: longitude);

    _locationPingTimer?.cancel();
    _locationPingTimer = Timer.periodic(_locationPingInterval, (_) async {
      final position = await _getCurrentPosition();
      if (position != null) {
        ref
            .read(liveRequestsControllerProvider.notifier)
            .updateLocation(
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

  Future<Position?> _getCurrentPosition() => location_service.getCurrentPosition();
}

final craftsmanHomeControllerProvider =
    NotifierProvider<CraftsmanHomeController, CraftsmanHomeState>(
      CraftsmanHomeController.new,
    );
