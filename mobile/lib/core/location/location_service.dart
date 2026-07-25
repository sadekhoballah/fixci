import 'package:geolocator/geolocator.dart';

// Shared check→request→fetch sequence, previously duplicated between the
// client's ServiceRequestController and the craftsman's
// CraftsmanHomeController. Returns null if location services are off or
// permission was denied — callers decide how to surface that.
Future<Position?> getCurrentPosition() async {
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
