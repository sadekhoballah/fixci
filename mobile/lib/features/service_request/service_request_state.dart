enum ServiceRequestStatus {
  idle,
  locating,
  submitting,
  searching,
  assigned,
  noCraftsmanAvailable,
  error,
}

class ServiceRequestState {
  const ServiceRequestState({
    this.status = ServiceRequestStatus.idle,
    this.requestId,
    this.errorMessage,
  });

  final ServiceRequestStatus status;
  final String? requestId;
  final String? errorMessage;

  ServiceRequestState copyWith({
    ServiceRequestStatus? status,
    String? requestId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ServiceRequestState(
      status: status ?? this.status,
      requestId: requestId ?? this.requestId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
