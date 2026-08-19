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

// Covers the *whole* sequence below (permission check + request + fix), not
// just the final GPS fetch. The permission step has no timeout of its own,
// and on Android, two screens racing to call this at once — e.g. the
// Missions tab and the Home tab both mounting together inside an
// IndexedStack right after login/registration, before permission has ever
// been granted — can leave one caller's requestPermission() waiting on a
// native callback that never arrives. Reproduced live: without this outer
// bound, that caller stayed stuck "loading" until the app was killed and
// relaunched (at which point permission was already granted, so
// checkPermission short-circuits and no race happens). A few extra seconds
// of slack over _positionTimeLimit for the permission dialog itself.
const _overallTimeLimit = Duration(seconds: 25);

// Shared check→request→fetch sequence, previously duplicated between the
// client's ServiceRequestController and the craftsman's
// CraftsmanHomeController. Returns null if location services are off,
// permission was denied, no fix arrived within _positionTimeLimit, or
// anything in the sequence took longer than _overallTimeLimit — callers
// decide how to surface that. Never throws and never hangs past
// _overallTimeLimit: every caller treats this as "best effort", so any
// platform/plugin failure collapses to the same null path as a plain
// denial.
Future<Position?> getCurrentPosition() async {
  try {
    return await _fetchPosition().timeout(_overallTimeLimit);
  } catch (_) {
    return null;
  }
}

Future<Position?> _fetchPosition() async {
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
