import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';
import '../../core/realtime/matching_socket_service.dart';
import 'craftsman_home_repository.dart';
import 'live_requests_state.dart';

// Mirrors the backend's ACCEPT_TIMEOUT_MS (matching.constants.ts) — used
// only to drive the local countdown display; the backend's own timeout is
// what actually decides when a round is abandoned.
const acceptTimeout = Duration(seconds: 18);

// Owns the realtime side of the craftsman experience end to end: the socket
// connection, the incoming-request feed, and the active job — kept separate
// from CraftsmanHomeController (profile/stats, REST-only) since this has a
// fundamentally different lifecycle (a long-lived connection with push
// events, not a one-shot load).
class LiveRequestsController extends Notifier<LiveRequestsState> {
  StreamSubscription<IncomingRequestEvent>? _newSub;
  StreamSubscription<RequestAssignedEvent>? _assignedSub;
  StreamSubscription<RequestOutcomeEvent>? _unavailableSub;
  StreamSubscription<RequestOutcomeEvent>? _completedSub;
  StreamSubscription<RequestOutcomeEvent>? _cancelledSub;
  StreamSubscription<SocketConnectionStatus>? _statusSub;
  Timer? _countdownTicker;
  bool _shouldBeListening = false;

  @override
  LiveRequestsState build() {
    final socket = ref.watch(matchingSocketServiceProvider);

    _newSub = socket.onRequestNew.listen(_onRequestNew);
    _assignedSub = socket.onRequestAssigned.listen(_onRequestAssigned);
    _unavailableSub = socket.onRequestUnavailable.listen(_onRequestUnavailable);
    // The client confirmed completion of the job we marked done — refresh so
    // the active-job card clears instead of sitting on "En attente...".
    _completedSub = socket.onRequestCompleted.listen((_) {
      unawaited(loadActiveJob());
    });
    // The client backed out of a job still assigned to us (matching.gateway.ts
    // notifyCraftsman('request:cancelled')) — without this, activeJob just sat
    // there showing "Mission acceptée" with live action buttons until the next
    // app resume or pull-to-refresh happened to call loadActiveJob() on its own.
    _cancelledSub = socket.onRequestCancelled.listen(_onRequestCancelled);
    _statusSub = socket.connectionStatus.listen((status) {
      state = state.copyWith(connectionStatus: status);
    });
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _pruneExpiredRequests();
    });

    ref.onDispose(() {
      _newSub?.cancel();
      _assignedSub?.cancel();
      _unavailableSub?.cancel();
      _completedSub?.cancel();
      _cancelledSub?.cancel();
      _statusSub?.cancel();
      _countdownTicker?.cancel();
    });

    Future.microtask(loadActiveJob);
    return const LiveRequestsState();
  }

  Future<void> loadActiveJob() async {
    state = state.copyWith(isLoadingActiveJob: true);
    try {
      final activeJob = await ref
          .read(craftsmanHomeRepositoryProvider)
          .getActiveJob();
      state = state.copyWith(
        isLoadingActiveJob: false,
        activeJob: activeJob,
        clearActiveJob: activeJob == null,
      );
    } catch (_) {
      state = state.copyWith(isLoadingActiveJob: false);
    }
  }

  void startListening({
    required ServiceCategory category,
    required double latitude,
    required double longitude,
  }) {
    _shouldBeListening = true;
    final socket = ref.read(matchingSocketServiceProvider);
    socket.connect();
    // goOnline is only actually sent once the socket finishes connecting —
    // socket_io_client queues emits made before "connect" fires and flushes
    // them once it does, so this is safe to call immediately.
    socket.goOnline(category: category, latitude: latitude, longitude: longitude);
  }

  void updateLocation({required double latitude, required double longitude}) {
    if (!_shouldBeListening) return;
    ref
        .read(matchingSocketServiceProvider)
        .updateLocation(latitude: latitude, longitude: longitude);
  }

  void stopListening() {
    _shouldBeListening = false;
    final socket = ref.read(matchingSocketServiceProvider);
    socket.goOffline();
    socket.disconnect();
    state = state.copyWith(incomingRequests: []);
  }

  // Called when the app returns to the foreground: the socket may have
  // dropped while backgrounded (OS-suspended sockets, network changes) —
  // reconnect if we're supposed to be online, and refresh the active job in
  // case something changed (e.g. it expired) while we were away.
  void handleAppResumed({
    required ServiceCategory category,
    required double latitude,
    required double longitude,
  }) {
    if (_shouldBeListening && !ref.read(matchingSocketServiceProvider).isConnected) {
      startListening(category: category, latitude: latitude, longitude: longitude);
    }
    unawaited(loadActiveJob());
  }

  Future<void> acceptRequest(String requestId) async {
    ref.read(matchingSocketServiceProvider).acceptRequest(requestId);
  }

  // Purely a local dismissal — the backend has no per-craftsman "decline"
  // concept (see matching.gateway.ts: a round either gets accepted or times
  // out for everyone), so there's nothing to tell it. If the round is still
  // running, other candidates are unaffected.
  void declineRequest(String requestId) {
    _removeIncomingRequest(requestId);
  }

  Future<bool> startJob(String requestId) =>
      _runAction(() => ref.read(craftsmanHomeRepositoryProvider).startJob(requestId));

  Future<bool> completeJob(String requestId) => _runAction(() async {
    await ref.read(craftsmanHomeRepositoryProvider).completeJob(requestId);
    state = state.copyWith(clearActiveJob: true);
  });

  Future<bool> cancelJob(String requestId) => _runAction(() async {
    await ref.read(craftsmanHomeRepositoryProvider).cancelJob(requestId);
    state = state.copyWith(clearActiveJob: true);
  });

  Future<bool> _runAction(Future<void> Function() action) async {
    state = state.copyWith(isProcessingAction: true, clearActionError: true);
    try {
      await action();
      state = state.copyWith(isProcessingAction: false);
      await loadActiveJob();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isProcessingAction: false, actionError: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isProcessingAction: false,
        actionError: "Une erreur est survenue.",
      );
      return false;
    }
  }

  void _onRequestNew(IncomingRequestEvent event) {
    if (state.incomingRequests.any((r) => r.requestId == event.requestId)) {
      return;
    }
    state = state.copyWith(
      incomingRequests: [
        ...state.incomingRequests,
        IncomingRequest(event: event, receivedAt: DateTime.now()),
      ],
    );
  }

  void _onRequestAssigned(RequestAssignedEvent event) {
    final wasMine = state.incomingRequests.any(
      (r) => r.requestId == event.requestId,
    );
    _removeIncomingRequest(event.requestId);
    if (wasMine) {
      unawaited(loadActiveJob());
    }
  }

  void _onRequestUnavailable(RequestOutcomeEvent event) {
    _removeIncomingRequest(event.requestId);
  }

  void _onRequestCancelled(RequestOutcomeEvent event) {
    if (state.activeJob?.requestId != event.requestId) return;
    state = state.copyWith(
      clearActiveJob: true,
      actionError: 'Le client a annulé cette demande.',
    );
  }

  void _removeIncomingRequest(String requestId) {
    state = state.copyWith(
      incomingRequests: state.incomingRequests
          .where((r) => r.requestId != requestId)
          .toList(),
    );
  }

  void _pruneExpiredRequests() {
    if (state.incomingRequests.isEmpty) return;
    final now = DateTime.now();
    // A little slack past the backend's own timeout so a request:unavailable
    // that's already in flight gets to arrive and remove it normally first —
    // this is only the fallback for if that event is ever missed.
    final cutoff = acceptTimeout + const Duration(seconds: 3);
    final remaining = state.incomingRequests
        .where((r) => now.difference(r.receivedAt) < cutoff)
        .toList();
    if (remaining.length != state.incomingRequests.length) {
      state = state.copyWith(incomingRequests: remaining);
    }
  }
}

final liveRequestsControllerProvider =
    NotifierProvider<LiveRequestsController, LiveRequestsState>(
      LiveRequestsController.new,
    );
