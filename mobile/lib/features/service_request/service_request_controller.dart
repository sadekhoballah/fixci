import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/location/location_service.dart' as location_service;
import '../../core/models/service_category.dart';
import '../../core/network/api_client.dart';
import '../../core/realtime/matching_socket_service.dart';
import 'service_request_repository.dart';
import 'service_request_state.dart';

// Owns one request-and-wait attempt: geolocate, POST /matching/requests, then
// listen on the matching socket for how the backend's runMatchingLoop
// (matching.gateway.ts) resolves it. Scoped to the trade-detail + searching
// screens (autoDispose) — a fresh attempt starts clean each time either is
// reopened.
class ServiceRequestController extends Notifier<ServiceRequestState> {
  StreamSubscription<RequestAssignedEvent>? _assignedSub;
  StreamSubscription<RequestOutcomeEvent>? _noCraftsmanSub;
  StreamSubscription<CraftsmanLocationEvent>? _locationSub;
  StreamSubscription<RequestOutcomeEvent>? _startedSub;
  StreamSubscription<RequestOutcomeEvent>? _awaitingConfirmationSub;
  // Captured directly (rather than read via `ref` inside onDispose below) —
  // Riverpod forbids using `ref` from within a dispose callback.
  MatchingSocketService? _socket;

  @override
  ServiceRequestState build() {
    ref.onDispose(() {
      _assignedSub?.cancel();
      _noCraftsmanSub?.cancel();
      _locationSub?.cancel();
      _startedSub?.cancel();
      _awaitingConfirmationSub?.cancel();
      _socket?.disconnect();
    });
    return const ServiceRequestState();
  }

  // Fired as soon as the trade-detail screen opens, so the OS permission
  // prompt (and a first GPS fix) happens well before the user taps "Demander
  // maintenant" — submit() below still geolocates itself, but resolves
  // near-instantly once permission is already granted.
  Future<void> prewarmLocation() async {
    await location_service.getCurrentPosition();
  }

  // Mirrors CraftsmanHomeController.requestLocationAccess's sequence, applied
  // to the client's own request flow: request the app permission if that's
  // the blocker, then deep-link straight to the relevant system settings
  // screen instead of just telling the client to go find it themselves —
  // neither platform lets an app flip location on programmatically, so a
  // direct settings deep-link is the closest thing to "automatic activation"
  // available. Returns null (with state already set to an actionable error)
  // if location still isn't available after this.
  Future<Position?> _resolvePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      state = state.copyWith(
        status: ServiceRequestStatus.error,
        errorMessage: 'Activez la localisation puis réessayez.',
      );
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      state = state.copyWith(
        status: ServiceRequestStatus.error,
        errorMessage: "Autorisez l'accès à la localisation puis réessayez.",
      );
      return null;
    }
    if (permission == LocationPermission.denied) {
      state = state.copyWith(
        status: ServiceRequestStatus.error,
        errorMessage: 'Localisation refusée.',
      );
      return null;
    }

    final position = await location_service.getCurrentPosition();
    if (position == null) {
      state = state.copyWith(
        status: ServiceRequestStatus.error,
        errorMessage: 'Impossible de récupérer votre position.',
      );
    }
    return position;
  }

  Future<void> submit(ServiceCategory category) async {
    state = state.copyWith(
      status: ServiceRequestStatus.locating,
      clearError: true,
    );
    final position = await _resolvePosition();
    if (position == null) return;

    state = state.copyWith(
      status: ServiceRequestStatus.submitting,
      myLatitude: position.latitude,
      myLongitude: position.longitude,
    );
    try {
      final requestId = await ref
          .read(serviceRequestRepositoryProvider)
          .createRequest(
            category: category,
            latitude: position.latitude,
            longitude: position.longitude,
          );
      _listenForOutcome(requestId);
      state = state.copyWith(
        status: ServiceRequestStatus.searching,
        requestId: requestId,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: ServiceRequestStatus.error,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: ServiceRequestStatus.error,
        errorMessage: 'Une erreur est survenue.',
      );
    }
  }

  // Lets the client back out any time before the job is actually underway —
  // still searching, or waiting on the craftsman they matched with. Mirrors
  // matching.controller.ts's role-branch on the same PATCH .../cancel route.
  Future<void> cancel() async {
    final requestId = state.requestId;
    if (requestId == null || state.isCancelling) return;
    state = state.copyWith(isCancelling: true, clearError: true);
    try {
      await ref
          .read(serviceRequestRepositoryProvider)
          .cancelRequest(requestId);
      _assignedSub?.cancel();
      _noCraftsmanSub?.cancel();
      _locationSub?.cancel();
      _startedSub?.cancel();
      _awaitingConfirmationSub?.cancel();
      _socket?.disconnect();
      state = state.copyWith(
        status: ServiceRequestStatus.cancelled,
        isCancelling: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isCancelling: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isCancelling: false,
        errorMessage: "Impossible d'annuler la demande.",
      );
    }
  }

  void retry(ServiceCategory category) {
    _assignedSub?.cancel();
    _noCraftsmanSub?.cancel();
    _locationSub?.cancel();
    _startedSub?.cancel();
    _awaitingConfirmationSub?.cancel();
    state = const ServiceRequestState();
    unawaited(submit(category));
  }

  void _listenForOutcome(String requestId) {
    final socket = ref.read(matchingSocketServiceProvider);
    _socket = socket;
    socket.connect();
    socket.joinAsClient();
    _assignedSub = socket.onRequestAssigned.listen((event) {
      if (event.requestId != requestId) return;
      state = state.copyWith(
        status: ServiceRequestStatus.assigned,
        craftsmanFullName: event.craftsmanFullName,
        craftsmanPhone: event.craftsmanPhone,
      );
    });
    _noCraftsmanSub = socket.onNoCraftsmanAvailable.listen((event) {
      if (event.requestId != requestId) return;
      state = state.copyWith(status: ServiceRequestStatus.noCraftsmanAvailable);
    });
    _locationSub = socket.onCraftsmanLocationUpdate.listen((event) {
      state = state.copyWith(
        craftsmanLatitude: event.latitude,
        craftsmanLongitude: event.longitude,
      );
    });
    _startedSub = socket.onRequestStarted.listen((event) {
      if (event.requestId != requestId) return;
      state = state.copyWith(status: ServiceRequestStatus.inProgress);
    });
    _awaitingConfirmationSub = socket.onRequestAwaitingConfirmation.listen((
      event,
    ) {
      if (event.requestId != requestId) return;
      state = state.copyWith(
        status: ServiceRequestStatus.awaitingClientConfirmation,
      );
    });
  }

  // Client's half of mutual completion — confirms a job the craftsman has
  // already marked done via /complete. See matching.controller.ts's
  // confirm-complete endpoint.
  Future<void> confirmCompletion() async {
    final requestId = state.requestId;
    if (requestId == null || state.isConfirming) return;
    state = state.copyWith(isConfirming: true, clearError: true);
    try {
      await ref
          .read(serviceRequestRepositoryProvider)
          .confirmCompletion(requestId);
      _assignedSub?.cancel();
      _noCraftsmanSub?.cancel();
      _locationSub?.cancel();
      _startedSub?.cancel();
      _awaitingConfirmationSub?.cancel();
      _socket?.disconnect();
      state = state.copyWith(
        status: ServiceRequestStatus.completed,
        isConfirming: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isConfirming: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isConfirming: false,
        errorMessage: 'Impossible de confirmer la fin de la mission.',
      );
    }
  }

  Future<void> submitRating({required int stars, String? comment}) async {
    final requestId = state.requestId;
    if (requestId == null || state.isSubmittingRating) return;
    state = state.copyWith(isSubmittingRating: true, clearError: true);
    try {
      await ref
          .read(serviceRequestRepositoryProvider)
          .submitRating(requestId, stars: stars, comment: comment);
      state = state.copyWith(
        status: ServiceRequestStatus.rated,
        isSubmittingRating: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isSubmittingRating: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isSubmittingRating: false,
        errorMessage: "Impossible d'envoyer votre évaluation.",
      );
    }
  }

  void skipRating() {
    state = state.copyWith(status: ServiceRequestStatus.rated);
  }
}

final serviceRequestControllerProvider = NotifierProvider.autoDispose<
  ServiceRequestController,
  ServiceRequestState
>(ServiceRequestController.new);
