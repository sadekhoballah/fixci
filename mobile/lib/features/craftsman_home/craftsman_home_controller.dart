import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/auth/session_storage.dart';
import '../../core/network/api_client.dart';
import 'craftsman_home_repository.dart';
import 'craftsman_home_state.dart';

class CraftsmanHomeController extends Notifier<CraftsmanHomeState> {
  String? _phone;

  @override
  CraftsmanHomeState build() {
    Future.microtask(_load);
    return const CraftsmanHomeState();
  }

  Future<void> _load() async {
    final phone = await ref.read(sessionStorageProvider).loadPhone();
    if (phone == null) return;
    _phone = phone;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(craftsmanHomeRepositoryProvider);
      final me = await repository.getMe(phone);
      final stats = await repository.getStats(phone);
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

  Future<void> refreshStats() async {
    final phone = _phone;
    if (phone == null) return;
    try {
      final stats = await ref
          .read(craftsmanHomeRepositoryProvider)
          .getStats(phone);
      state = state.copyWith(stats: stats);
    } catch (_) {
      // Silent — the stats bar just keeps showing the last known numbers.
    }
  }

  Future<void> toggleAvailability(bool wantsAvailable) async {
    final phone = _phone;
    if (phone == null || state.isTogglingAvailability) return;

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
            phone,
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
