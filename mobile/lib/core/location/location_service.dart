import 'dart:async';

import 'package:geolocator/geolocator.dart';

// Reproduced live during testing: with no time limit, a GPS fix that never
// arrives (weak signal, indoors) leaves Geolocator.getCurrentPosition
// hanging forever — the client's "Recherche…" screen would sit frozen with
// no error and no way to cancel, since nothing downstream of this call ever
// gets a chance to run. Every caller here already treats a null result as
// "couldn't get a position" and surfaces its own error, so timing out into
// that same null path is a drop-in fix, not a new failure mode.
const _positionTimeLimit = Duration(seconds: 20);

// Shared check→request→fetch sequence, previously duplicated between the
// client's ServiceRequestController and the craftsman's
// CraftsmanHomeController. Returns null if location services are off,
// permission was denied, or no fix arrived within _positionTimeLimit —
// callers decide how to surface that.
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

  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: _positionTimeLimit,
      ),
    );
  } on TimeoutException {
    return null;
  }
}
