enum ServiceRequestStatus {
  idle,
  locating,
  submitting,
  searching,
  assigned,
  inProgress,
  awaitingClientConfirmation,
  completed,
  rated,
  noCraftsmanAvailable,
  cancelled,
  error,
}

class ServiceRequestState {
  const ServiceRequestState({
    this.status = ServiceRequestStatus.idle,
    this.requestId,
    this.errorMessage,
    this.myLatitude,
    this.myLongitude,
    this.destinationAddress,
    this.loadDetails,
    this.craftsmanFullName,
    this.craftsmanPhone,
    this.craftsmanLatitude,
    this.craftsmanLongitude,
    this.isCancelling = false,
    this.isConfirming = false,
    this.isSubmittingRating = false,
  });

  final ServiceRequestStatus status;
  final String? requestId;
  final String? errorMessage;
  // The client's own location, captured once at submit time — used to
  // compute a live distance/ETA readout against the craftsman's updates.
  final double? myLatitude;
  final double? myLongitude;
  // Taxi/camion only — captured at submit time so retry() (which resets the
  // rest of the state) can resubmit the same values instead of silently
  // dropping them.
  final String? destinationAddress;
  final String? loadDetails;
  final String? craftsmanFullName;
  final String? craftsmanPhone;
  final double? craftsmanLatitude;
  final double? craftsmanLongitude;
  final bool isCancelling;
  // Client tapped "Confirmer la fin de la mission", awaiting the backend.
  final bool isConfirming;
  final bool isSubmittingRating;

  ServiceRequestState copyWith({
    ServiceRequestStatus? status,
    String? requestId,
    String? errorMessage,
    bool clearError = false,
    double? myLatitude,
    double? myLongitude,
    String? destinationAddress,
    String? loadDetails,
    String? craftsmanFullName,
    String? craftsmanPhone,
    double? craftsmanLatitude,
    double? craftsmanLongitude,
    bool? isCancelling,
    bool? isConfirming,
    bool? isSubmittingRating,
  }) {
    return ServiceRequestState(
      status: status ?? this.status,
      requestId: requestId ?? this.requestId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      myLatitude: myLatitude ?? this.myLatitude,
      myLongitude: myLongitude ?? this.myLongitude,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      loadDetails: loadDetails ?? this.loadDetails,
      craftsmanFullName: craftsmanFullName ?? this.craftsmanFullName,
      craftsmanPhone: craftsmanPhone ?? this.craftsmanPhone,
      craftsmanLatitude: craftsmanLatitude ?? this.craftsmanLatitude,
      craftsmanLongitude: craftsmanLongitude ?? this.craftsmanLongitude,
      isCancelling: isCancelling ?? this.isCancelling,
      isConfirming: isConfirming ?? this.isConfirming,
      isSubmittingRating: isSubmittingRating ?? this.isSubmittingRating,
    );
  }
}
