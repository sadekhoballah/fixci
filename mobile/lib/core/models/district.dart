// Not a hardcoded enum like ServiceCategory: the founder can add new
// districts from the admin panel without an app release, so the list is
// always fetched from GET /districts rather than baked into the app.
class District {
  const District({
    required this.id,
    required this.name,
    required this.isArtisanRegistrationActive,
    required this.isClientOrderingActive,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'] as String,
      name: json['name'] as String,
      isArtisanRegistrationActive:
          json['isArtisanRegistrationActive'] as bool,
      isClientOrderingActive: json['isClientOrderingActive'] as bool,
    );
  }

  final String id;
  final String name;
  final bool isArtisanRegistrationActive;
  final bool isClientOrderingActive;
}
