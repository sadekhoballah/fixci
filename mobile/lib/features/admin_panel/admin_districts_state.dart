class DistrictWithCounts {
  const DistrictWithCounts({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.isArtisanRegistrationActive,
    required this.isClientOrderingActive,
    required this.artisansCount,
    required this.verifiedArtisansCount,
    required this.clientsCount,
  });

  final String id;
  final String name;
  final String countryCode;
  final bool isArtisanRegistrationActive;
  final bool isClientOrderingActive;
  final int artisansCount;
  // ID approved and account active — what tells whether a waitlisted city
  // can be opened to clients (see kCityReadyThreshold).
  final int verifiedArtisansCount;
  final int clientsCount;

  DistrictWithCounts copyWith({
    bool? isArtisanRegistrationActive,
    bool? isClientOrderingActive,
  }) {
    return DistrictWithCounts(
      id: id,
      name: name,
      countryCode: countryCode,
      isArtisanRegistrationActive:
          isArtisanRegistrationActive ?? this.isArtisanRegistrationActive,
      isClientOrderingActive:
          isClientOrderingActive ?? this.isClientOrderingActive,
      artisansCount: artisansCount,
      verifiedArtisansCount: verifiedArtisansCount,
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
