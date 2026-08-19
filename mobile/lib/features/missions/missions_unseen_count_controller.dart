import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'missions_repository.dart';

// Persistent tab controller (not autoDispose), same rationale as
// MissionsBoardController — backs the Missions bottom-nav badge in both
// app shells (ClientShellScreen/ArtisanShellScreen), which need the count
// even while the Missions tab itself is never mounted.
class MissionsUnseenCountController extends Notifier<int> {
  @override
  int build() {
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    try {
      final count = await ref.read(missionsRepositoryProvider).getUnseenCount();
      state = count;
    } catch (_) {
      // Best-effort — a failed poll just leaves the last-known badge count
      // on screen rather than flashing it to zero or an error state.
    }
  }

  // Called when the Missions tab opens (see missions_home_screen.dart) —
  // optimistically zeroes the badge immediately rather than waiting on the
  // round trip, since there's nothing useful to show while it's in flight.
  Future<void> markSeen() async {
    state = 0;
    try {
      await ref.read(missionsRepositoryProvider).markSeen();
    } catch (_) {
      // Best-effort — worst case the next refresh() brings the count back.
    }
  }
}

final missionsUnseenCountControllerProvider =
    NotifierProvider<MissionsUnseenCountController, int>(
      MissionsUnseenCountController.new,
    );
