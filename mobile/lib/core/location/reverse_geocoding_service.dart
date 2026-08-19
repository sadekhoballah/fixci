import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

// Best-effort GPS -> human-readable address, via the phone's own native
// geocoder (Android Geocoder / iOS CLGeocoder) rather than a Maps API call —
// free, no API key, consistent with this app's existing choice to never
// configure google_maps_flutter (see CreateMissionDto). A caller with no
// network or a device with no geocoder backend just keeps showing the raw
// stored address instead — this never throws and never hangs past
// _timeLimit.
//
// In-memory cache only, keyed to ~11m precision (4 decimal places) so
// missions sitting on the same block share one lookup instead of re-hitting
// the platform geocoder on every rebuild/scroll. Cleared on app restart —
// that's fine, it's purely an optimization, not correctness-bearing.
class ReverseGeocodingService {
  final Map<String, String?> _cache = {};
  // geocoding 5.x dropped the old top-level placemarkFromCoordinates()
  // function in favor of this instance-based API — same native
  // Android Geocoder / iOS CLGeocoder backend, just a different entry point.
  final Geocoding _geocoding = Geocoding();

  static const _timeLimit = Duration(seconds: 8);

  Future<String?> lookup(double latitude, double longitude) async {
    final key =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) return _cache[key];

    String? address;
    try {
      final placemarks = await _geocoding
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(_timeLimit);
      if (placemarks.isNotEmpty) {
        address = _format(placemarks.first);
      }
    } catch (_) {
      // No geocoder backend on this device, no network, timed out, ... —
      // every reason collapses to "couldn't resolve", same best-effort
      // contract as location_service.getCurrentPosition.
      address = null;
    }
    _cache[key] = address;
    return address;
  }

  String? _format(Placemark placemark) {
    final parts = [
      placemark.subLocality,
      placemark.locality,
      placemark.administrativeArea,
    ].where((part) => part != null && part.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}

final reverseGeocodingServiceProvider = Provider<ReverseGeocodingService>(
  (ref) => ReverseGeocodingService(),
);
