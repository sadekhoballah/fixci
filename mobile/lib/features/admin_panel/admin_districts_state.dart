class DistrictWithCounts {
  const DistrictWithCounts({
    required this.id,
    required this.name,
    required this.isArtisanRegistrationActive,
    required this.isClientOrderingActive,
    required this.artisansCount,
    required this.clientsCount,
  });

  final String id;
  final String name;
  final bool isArtisanRegistrationActive;
  final bool isClientOrderingActive;
  final int artisansCount;
  final int clientsCount;

  DistrictWithCounts copyWith({
    bool? isArtisanRegistrationActive,
    bool? isClientOrderingActive,
  }) {
    return DistrictWithCounts(
      id: id,
      name: name,
      isArtisanRegistrationActive:
          isArtisanRegistrationActive ?? this.isArtisanRegistrationActive,
      isClientOrderingActive:
          isClientOrderingActive ?? this.isClientOrderingActive,
      artisansCount: artisansCount,
      clientsCount: clientsCount,
    );
  }
}

class AdminDistrictsState {
  const AdminDistrictsState({
    this.districts = const [],
    this.isLoading = true,
    this.errorMessage,
    this.processingDistrictIds = const {},
  });

  final List<DistrictWithCounts> districts;
  final bool isLoading;
  final String? errorMessage;
  // Which rows currently have a toggle/create request in flight.
  final Set<String> processingDistrictIds;

  AdminDistrictsState copyWith({
    List<DistrictWithCounts>? districts,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Set<String>? processingDistrictIds,
  }) {
    return AdminDistrictsState(
      districts: districts ?? this.districts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      processingDistrictIds:
          processingDistrictIds ?? this.processingDistrictIds,
    );
  }
}
