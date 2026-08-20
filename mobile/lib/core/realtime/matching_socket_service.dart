import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../auth/current_auth_token.dart';
import '../models/service_category.dart';
import '../network/api_config.dart';

class IncomingRequestEvent {
  const IncomingRequestEvent({
    required this.requestId,
    required this.serviceCategory,
    required this.distanceMeters,
    required this.estimatedArrivalMinutes,
    this.destinationAddress,
    this.loadDetails,
  });

  factory IncomingRequestEvent.fromJson(Map<String, dynamic> json) {
    return IncomingRequestEvent(
      requestId: json['requestId'] as String,
      serviceCategory: _parseCategory(json['serviceCategory'] as String),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      estimatedArrivalMinutes: json['estimatedArrivalMinutes'] as int,
      destinationAddress: json['destinationAddress'] as String?,
      loadDetails: json['loadDetails'] as String?,
    );
  }

  final String requestId;
  final ServiceCategory serviceCategory;
  final double distanceMeters;
  final int estimatedArrivalMinutes;
  // Taxi/camion only — see ServiceCategory.requiresDestination.
  final String? destinationAddress;
  final String? loadDetails;
}

ServiceCategory _parseCategory(String wireValue) => ServiceCategory.values
    .firstWhere((c) => c.wireValue == wireValue, orElse: () => ServiceCategory.plumber);

class RequestOutcomeEvent {
  const RequestOutcomeEvent(this.requestId);

  factory RequestOutcomeEvent.fromJson(Map<String, dynamic> json) =>
      RequestOutcomeEvent(json['requestId'] as String);

  final String requestId;
}

// request:assigned carries extra fields when it reaches the client (the
// craftsman's name/phone) — craftsman-side listeners only ever read
// requestId, so those fields are simply null on that side of the wire.
class RequestAssignedEvent {
  const RequestAssignedEvent({
    required this.requestId,
    this.craftsmanId,
    this.craftsmanFullName,
    this.craftsmanPhone,
  });

  factory RequestAssignedEvent.fromJson(Map<String, dynamic> json) {
    return RequestAssignedEvent(
      requestId: json['requestId'] as String,
      craftsmanId: json['craftsmanId'] as String?,
      craftsmanFullName: json['craftsmanFullName'] as String?,
      craftsmanPhone: json['craftsmanPhone'] as String?,
    );
  }

  final String requestId;
  final String? craftsmanId;
  final String? craftsmanFullName;
  final String? craftsmanPhone;
}

class CraftsmanLocationEvent {
  const CraftsmanLocationEvent({required this.latitude, required this.longitude});

  factory CraftsmanLocationEvent.fromJson(Map<String, dynamic> json) {
    return CraftsmanLocationEvent(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  final double latitude;
  final double longitude;
}

enum SocketConnectionStatus { disconnected, connecting, connected }

// Wraps the raw socket.io connection to the backend's MatchingGateway. Every
// method here mirrors an event the gateway actually understands (see
// matching.gateway.ts) — this is the mobile half of the realtime matching
// loop that already exists server-side.
class MatchingSocketService {
  socket_io.Socket? _socket;
  // Reconnect resilience: socket.io's auto-reconnect (setReconnectionAttempts
  // below) brings the transport back up transparently after a drop, but the
  // *server* has no memory of which room this socket was in — matching.gateway.ts's
  // client:join/craftsman:online handlers are what put it there, and those
  // only ever ran once, on the original connect. Without replaying them on
  // every 'connect' event (which socket.io fires again after each successful
  // reconnect, not just the first), a socket that drops and recovers mid-request
  // — very plausible on a real mobile network — silently stops receiving
  // anything for that room forever, even though isConnected reports true.
  bool _wantsClientJoin = false;
  ({ServiceCategory category, double latitude, double longitude})?
  _craftsmanOnlineParams;

  final _requestNewController =
      StreamController<IncomingRequestEvent>.broadcast();
  final _requestAssignedController =
      StreamController<RequestAssignedEvent>.broadcast();
  final _requestUnavailableController =
      StreamController<RequestOutcomeEvent>.broadcast();
  final _noCraftsmanAvailableController =
      StreamController<RequestOutcomeEvent>.broadcast();
  final _craftsmanLocationController =
      StreamController<CraftsmanLocationEvent>.broadcast();
  final _requestStartedController =
      StreamController<RequestOutcomeEvent>.broadcast();
  final _requestAwaitingConfirmationController =
      StreamController<RequestOutcomeEvent>.broadcast();
  final _requestCompletedController =
      StreamController<RequestOutcomeEvent>.broadcast();
  final _requestCancelledController =
      StreamController<RequestOutcomeEvent>.broadcast();
  final _connectionStatusController =
      StreamController<SocketConnectionStatus>.broadcast();

  Stream<IncomingRequestEvent> get onRequestNew => _requestNewController.stream;
  Stream<RequestAssignedEvent> get onRequestAssigned =>
      _requestAssignedController.stream;
  Stream<RequestOutcomeEvent> get onRequestUnavailable =>
      _requestUnavailableController.stream;
  Stream<RequestOutcomeEvent> get onNoCraftsmanAvailable =>
      _noCraftsmanAvailableController.stream;
  Stream<CraftsmanLocationEvent> get onCraftsmanLocationUpdate =>
      _craftsmanLocationController.stream;
  // Client-side: the craftsman has started (request:started) or marked the
  // job done and is now awaiting the client's confirmation
  // (request:awaiting_confirmation).
  Stream<RequestOutcomeEvent> get onRequestStarted =>
      _requestStartedController.stream;
  Stream<RequestOutcomeEvent> get onRequestAwaitingConfirmation =>
      _requestAwaitingConfirmationController.stream;
  // Craftsman-side: the client just confirmed completion (request:completed).
  Stream<RequestOutcomeEvent> get onRequestCompleted =>
      _requestCompletedController.stream;
  // Craftsman-side: the client cancelled a request that was assigned to this
  // craftsman (matching.controller.ts's cancelByClient path) — the job was
  // still en route/pending confirmation, not yet in_progress.
  Stream<RequestOutcomeEvent> get onRequestCancelled =>
      _requestCancelledController.stream;
  Stream<SocketConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket != null) return; // already connecting/connected

    _connectionStatusController.add(SocketConnectionStatus.connecting);
    final socket = socket_io.io(
      ApiConfig.baseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(999999)
          .setAuthFn((callback) async {
            final token = await currentAuthToken();
            callback(<String, dynamic>{'token': ?token});
          })
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _connectionStatusController.add(SocketConnectionStatus.connected);
      // Replays whichever room this socket is supposed to be in — a no-op
      // duplicate of the direct emit in joinAsClient()/goOnline() on the very
      // first connect (harmless: joining a room twice server-side is
      // idempotent), and the actual fix on every reconnect after that.
      if (_wantsClientJoin) {
        socket.emit('client:join');
      }
      final onlineParams = _craftsmanOnlineParams;
      if (onlineParams != null) {
        socket.emit('craftsman:online', {
          'serviceCategory': onlineParams.category.wireValue,
          'latitude': onlineParams.latitude,
          'longitude': onlineParams.longitude,
        });
      }
    });
    socket.onDisconnect((_) {
      _connectionStatusController.add(SocketConnectionStatus.disconnected);
    });
    socket.onConnectError((error) {
      // Auth failures (expired access token, no matching account for the
      // phone — see matching.gateway.ts afterInit) land here and previously
      // vanished silently: the status stream just flipped to "disconnected"
      // with no way to tell that apart from a plain network drop. Unlike
      // ApiClient, this doesn't retry with a refreshed token — a dropped
      // socket already auto-reconnects (setReconnectionAttempts above) and
      // re-reads currentAuthToken() on every attempt, so a token refreshed
      // elsewhere (e.g. by the next REST call) is picked up on the very
      // next reconnect anyway.
      debugPrint('MatchingSocketService connect error: $error');
      _connectionStatusController.add(SocketConnectionStatus.disconnected);
    });
    socket.on('request:new', (data) {
      _requestNewController.add(
        IncomingRequestEvent.fromJson(data as Map<String, dynamic>),
      );
    });
    socket.on('request:assigned', (data) {
      _requestAssignedController.add(
        RequestAssignedEvent.fromJson(data as Map<String, dynamic>),
      );
    });
    socket.on('request:unavailable', (data) {
      _requestUnavailableController.add(
        RequestOutcomeEvent.fromJson(data as Map<String, dynamic>),
      );
    });
    socket.on('request:no_craftsman_available', (data) {
      _noCraftsmanAvailableController.add(
        RequestOutcomeEvent.fromJson(data as Map<String, dynamic>),
      );
    });
    socket.on('craftsman:location:update', (data) {
      _craftsmanLocationController.add(
        CraftsmanLocationEvent.fromJson(data as Map<String, dynamic>),
      );
    });
    socket.on('request:started', (data) {
      _requestStartedController.add(
        RequestOutcomeEvent.fromJson(data as Map<String, dynamic>),
      );
    });
    socket.on('request:awaiting_confirmation', (data) {
      _requestAwaitingConfirmationController.add(
        RequestOutcomeEvent.fromJson(data as Map<String, dynamic>),
      );
    });
    socket.on('request:completed', (data) {
      _requestCompletedController.add(
        RequestOutcomeEvent.fromJson(data as Map<String, dynamic>),
      );
    });
    socket.on('request:cancelled', (data) {
      _requestCancelledController.add(
        RequestOutcomeEvent.fromJson(data as Map<String, dynamic>),
      );
    });

    socket.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _wantsClientJoin = false;
    _craftsmanOnlineParams = null;
    _connectionStatusController.add(SocketConnectionStatus.disconnected);
  }

  // Puts this socket in the caller's client room (matching.gateway.ts:
  // handleClientJoin) so notifyClient/runMatchingLoop pushes reach it. Safe to
  // call right after connect() — see the goOnline note below on queued emits.
  void joinAsClient() {
    _wantsClientJoin = true;
    _socket?.emit('client:join');
  }

  void goOnline({
    required ServiceCategory category,
    required double latitude,
    required double longitude,
  }) {
    _craftsmanOnlineParams = (
      category: category,
      latitude: latitude,
      longitude: longitude,
    );
    _socket?.emit('craftsman:online', {
      'serviceCategory': category.wireValue,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  void updateLocation({required double latitude, required double longitude}) {
    _socket?.emit('craftsman:location', {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  void goOffline() {
    _craftsmanOnlineParams = null;
    _socket?.emit('craftsman:offline', {});
  }

  void acceptRequest(String requestId) {
    _socket?.emit('request:accept', {'requestId': requestId});
  }

  void dispose() {
    disconnect();
    _requestNewController.close();
    _requestAssignedController.close();
    _requestUnavailableController.close();
    _noCraftsmanAvailableController.close();
    _craftsmanLocationController.close();
    _requestStartedController.close();
    _requestAwaitingConfirmationController.close();
    _requestCompletedController.close();
    _requestCancelledController.close();
    _connectionStatusController.close();
  }
}

final matchingSocketServiceProvider = Provider<MatchingSocketService>((ref) {
  final service = MatchingSocketService();
  ref.onDispose(service.dispose);
  return service;
});
