/// DVR permission levels for recording access control.
///
/// Controls what recording actions a user can perform.
enum DvrPermission {
  /// No DVR access - cannot view or schedule recordings.
  none(value: 0, label: 'None', description: 'No recording access'),

  /// Can view shared recordings only - cannot schedule or delete.
  viewOnly(
    value: 1,
    label: 'View Only',
    description: 'Can view shared recordings',
  ),

  /// Full DVR access - can view all, schedule, and delete own recordings.
  full(
    value: 2,
    label: 'Full Access',
    description: 'Can schedule, view, and delete recordings',
  );

  const DvrPermission({
    required this.value,
    required this.label,
    required this.description,
  });

  /// Numeric value for database storage.
  final int value;

  /// Human-readable label for UI display.
  final String label;

  /// Description of the permission level.
  final String description;

  /// Creates a DvrPermission from its database value.
  static DvrPermission fromValue(int value) {
    return DvrPermission.values.firstWhere(
      (perm) => perm.value == value,
      orElse: () => DvrPermission.viewOnly,
    );
  }

  /// Whether this permission allows viewing recordings.
  bool get canViewRecordings => this != DvrPermission.none;

  /// Whether this permission allows viewing only shared recordings.
  bool get viewSharedOnly => this == DvrPermission.viewOnly;

  /// Whether this permission allows scheduling new recordings.
  bool get canScheduleRecordings => this == DvrPermission.full;

  /// Whether this permission allows deleting own recordings.
  bool get canDeleteOwnRecordings => this == DvrPermission.full;
}
