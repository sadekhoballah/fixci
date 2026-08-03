enum UserRole {
  client,
  craftsman;

  // Matches the backend's user_role_enum string values.
  String get wireValue => switch (this) {
    UserRole.client => 'client',
    UserRole.craftsman => 'craftsman',
  };
}
