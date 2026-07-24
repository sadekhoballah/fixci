import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
  // Captured directly (rather than read via `ref` inside onDispose below) —
  // Riverpod forbids using `ref` from within a dispose callback.
  MatchingSocketService? _socket;

  @override
  ServiceRequestState build() {
    ref.onDispose(() {
      _assignedSub?.cancel();
      _noCraftsmanSub?.cancel();
      _locationSub?.cancel();
      _socket?.disconnect();
    });
    return const ServiceRequestState();
  }

  Future<void> submit(ServiceCategory category) async {
    state = state.copyWith(
      status: ServiceRequestStatus.locating,
      clearError: true,
    );
    final position = await _getCurrentPosition();
    if (position == null) {
      state = state.copyWith(
        status: ServiceRequestStatus.error,
        errorMessage: 'Activez la localisation pour envoyer une demande.',
      );
      return;
    }

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

final serviceRequestControllerProvider = NotifierProvider.autoDispose<
  ServiceRequestController,
  ServiceRequestState
>(ServiceRequestController.new);
