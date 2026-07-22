import '../../core/models/service_category.dart';
import '../../core/realtime/matching_socket_service.dart';

enum ActiveJobStatus { assigned, inProgress }

class ActiveJob {
  const ActiveJob({
    required this.requestId,
    required this.serviceCategory,
    required this.status,
    required this.clientFullName,
    required this.clientPhone,
    required this.clientLatitude,
    required this.clientLongitude,
    required this.assignedAt,
    required this.startedAt,
  });

  final String requestId;
  final ServiceCategory serviceCategory;
  final ActiveJobStatus status;
  final String? clientFullName;
  final String clientPhone;
  final double clientLatitude;
  final double clientLongitude;
  final DateTime assignedAt;
  final DateTime? startedAt;

  ActiveJob copyWith({ActiveJobStatus? status, DateTime? startedAt}) {
    return ActiveJob(
      requestId: requestId,
      serviceCategory: serviceCategory,
      status: status ?? this.status,
      clientFullName: clientFullName,
      clientPhone: clientPhone,
      clientLatitude: clientLatitude,
      clientLongitude: clientLongitude,
      assignedAt: assignedAt,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

// The UI-facing wrapper around a raw socket event: adds the local receipt
// timestamp the countdown is measured from (client-side only — the
// backend's own ACCEPT_TIMEOUT_MS is what actually decides when it expires).
class IncomingRequest {
  const IncomingRequest({required this.event, required this.receivedAt});

  final IncomingRequestEvent event;
  final DateTime receivedAt;

  String get requestId => event.requestId;
}

class LiveRequestsState {
  const LiveRequestsState({
    this.incomingRequests = const [],
    this.activeJob,
    this.isLoadingActiveJob = true,
    this.connectionStatus = SocketConnectionStatus.disconnected,
    this.isProcessingAction = false,
    this.actionError,
  });

  final List<IncomingRequest> incomingRequests;
  final ActiveJob? activeJob;
  final bool isLoadingActiveJob;
  final SocketConnectionStatus connectionStatus;
  final bool isProcessingAction;
  final String? actionError;

  LiveRequestsState copyWith({
    List<IncomingRequest>? incomingRequests,
    ActiveJob? activeJob,
    bool clearActiveJob = false,
    bool? isLoadingActiveJob,
    SocketConnectionStatus? connectionStatus,
    bool? isProcessingAction,
    String? actionError,
    bool clearActionError = false,
  }) {
    return LiveRequestsState(
      incomingRequests: incomingRequests ?? this.incomingRequests,
      activeJob: clearActiveJob ? null : (activeJob ?? this.activeJob),
      isLoadingActiveJob: isLoadingActiveJob ?? this.isLoadingActiveJob,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isProcessingAction: isProcessingAction ?? this.isProcessingAction,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }
}
