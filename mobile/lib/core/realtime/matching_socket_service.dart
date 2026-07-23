import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../auth/current_auth_token.dart';
import '../auth/dev_bypass_session.dart';
import '../models/service_category.dart';
import '../network/api_config.dart';

class IncomingRequestEvent {
  const IncomingRequestEvent({
    required this.requestId,
    required this.serviceCategory,
    required this.distanceMeters,
    required this.estimatedArrivalMinutes,
  });

  factory IncomingRequestEvent.fromJson(Map<String, dynamic> json) {
    return IncomingRequestEvent(
      requestId: json['requestId'] as String,
      serviceCategory: _parseCategory(json['serviceCategory'] as String),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      estimatedArrivalMinutes: json['estimatedArrivalMinutes'] as int,
    );
  }

  final String requestId;
  final ServiceCategory serviceCategory;
  final double distanceMeters;
  final int estimatedArrivalMinutes;
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
    this.craftsmanFullName,
    this.craftsmanPhone,
  });

  factory RequestAssignedEvent.fromJson(Map<String, dynamic> json) {
    return RequestAssignedEvent(
      requestId: json['requestId'] as String,
      craftsmanFullName: json['craftsmanFullName'] as String?,
      craftsmanPhone: json['craftsmanPhone'] as String?,
    );
  }

  final String requestId;
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
            final auth = <String, dynamic>{};
            final token = await currentAuthToken();
            if (token != null) {
              auth['token'] = token;
            } else if (devBypassPhone != null) {
              auth['devPhone'] = devBypassPhone;
            }
            callback(auth);
          })
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _connectionStatusController.add(SocketConnectionStatus.connected);
    });
    socket.onDisconnect((_) {
      _connectionStatusController.add(SocketConnectionStatus.disconnected);
    });
    socket.onConnectError((_) {
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

    socket.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionStatusController.add(SocketConnectionStatus.disconnected);
  }

  // Puts this socket in the caller's client room (matching.gateway.ts:
  // handleClientJoin) so notifyClient/runMatchingLoop pushes reach it. Safe to
  // call right after connect() — see the goOnline note below on queued emits.
  void joinAsClient() {
    _socket?.emit('client:join');
  }

  void goOnline({
    required ServiceCategory category,
    required double latitude,
    required double longitude,
  }) {
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
    _connectionStatusController.close();
  }
}

final matchingSocketServiceProvider = Provider<MatchingSocketService>((ref) {
  final service = MatchingSocketService();
  ref.onDispose(service.dispose);
  return service;
});
