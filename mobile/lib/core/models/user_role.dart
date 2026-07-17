enum UserRole {
  client,
  craftsman;

  String get label => switch (this) {
    UserRole.client => 'Client',
    UserRole.craftsman => 'Artisan',
  };

  String get description => switch (this) {
    UserRole.client => 'Je cherche un artisan',
    UserRole.craftsman => 'Je propose mes services',
  };
}
