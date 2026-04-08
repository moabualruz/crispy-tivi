/// User roles for access control in CrispyTivi.
///
/// Roles determine what features and settings a user can access.
enum UserRole {
  /// Full access to all features, settings, and profile management.
  admin(
    value: 0,
    label: 'Admin',
    description: 'Full access to all features and settings',
  ),

  /// Standard access with configurable DVR and source permissions.
  viewer(value: 1, label: 'Viewer', description: 'Standard viewing access'),

  /// Limited access with no settings and restricted content.
  restricted(
    value: 2,
    label: 'Restricted',
    description: 'Limited access for supervised viewing',
  );

  const UserRole({
    required this.value,
    required this.label,
    required this.description,
  });

  /// Numeric value for database storage.
  final int value;

  /// Human-readable label for UI display.
  final String label;

  /// Description of the role's capabilities.
  final String description;

  /// Creates a UserRole from its database value.
  static UserRole fromValue(int value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.viewer,
    );
  }

  /// Whether this role can access settings.
  ///
  /// Admin and viewer can both access settings.
  /// Only restricted profiles (supervised/kids) are blocked.
  bool get canAccessSettings => this != UserRole.restricted;

  /// Whether this role can manage other profiles.
  bool get canManageProfiles => this == UserRole.admin;

  /// Whether this role can access all sources by default.
  bool get hasAllSourceAccess => this == UserRole.admin;

  /// Whether this role has any DVR access by default.
  bool get hasDefaultDvrAccess => this != UserRole.restricted;
}
