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
    this.myLatitude,
    this.myLongitude,
    this.craftsmanFullName,
    this.craftsmanPhone,
    this.craftsmanLatitude,
    this.craftsmanLongitude,
  });

  final ServiceRequestStatus status;
  final String? requestId;
  final String? errorMessage;
  // The client's own location, captured once at submit time — used to
  // compute a live distance/ETA readout against the craftsman's updates.
  final double? myLatitude;
  final double? myLongitude;
  final String? craftsmanFullName;
  final String? craftsmanPhone;
  final double? craftsmanLatitude;
  final double? craftsmanLongitude;

  ServiceRequestState copyWith({
    ServiceRequestStatus? status,
    String? requestId,
    String? errorMessage,
    bool clearError = false,
    double? myLatitude,
    double? myLongitude,
    String? craftsmanFullName,
    String? craftsmanPhone,
    double? craftsmanLatitude,
    double? craftsmanLongitude,
  }) {
    return ServiceRequestState(
      status: status ?? this.status,
      requestId: requestId ?? this.requestId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      myLatitude: myLatitude ?? this.myLatitude,
      myLongitude: myLongitude ?? this.myLongitude,
      craftsmanFullName: craftsmanFullName ?? this.craftsmanFullName,
      craftsmanPhone: craftsmanPhone ?? this.craftsmanPhone,
      craftsmanLatitude: craftsmanLatitude ?? this.craftsmanLatitude,
      craftsmanLongitude: craftsmanLongitude ?? this.craftsmanLongitude,
    );
  }
}
