// Not a hardcoded enum like ServiceCategory: the founder can add new
// districts from the admin panel without an app release, so the list is
// always fetched from GET /districts rather than baked into the app.
class District {
  const District({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.isArtisanRegistrationActive,
    required this.isClientOrderingActive,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'] as String,
      name: json['name'] as String,
      countryCode: json['countryCode'] as String,
      isArtisanRegistrationActive:
          json['isArtisanRegistrationActive'] as bool,
      isClientOrderingActive: json['isClientOrderingActive'] as bool,
    );
  }

  final String id;
  final String name;
  // ISO 3166-1 alpha-2 — registration_screen.dart's _DistrictPicker filters
  // the (single, unfiltered) GET /districts response by this against
  // whichever country the phone field's IntlPhoneField currently has
  // selected, rather than the backend taking a country query param.
  final String countryCode;
  final bool isArtisanRegistrationActive;
  final bool isClientOrderingActive;
}
