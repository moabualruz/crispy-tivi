import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../data/profile_service.dart';
import '../data/source_access_service.dart';
import 'entities/user_profile.dart';
import 'enums/dvr_permission.dart';
import 'enums/user_role.dart';

/// Centralized permission checking utility.
///
/// Provides a consistent way to check various
/// permissions across the app.
class PermissionGuard {
  PermissionGuard(this._ref) : _backend = _ref.read(crispyBackendProvider);

  final Ref _ref;
  final CrispyBackend _backend;

  /// Gets the current active profile.
  UserProfile? get _currentProfile =>
      _ref.read(profileServiceProvider).value?.activeProfile;

  // ── Role-based checks ───────────────────────────────────────

  /// Whether the current user is an admin.
  bool get isAdmin => _currentProfile?.isAdmin ?? false;

  /// Whether the current user can access settings.
  bool get canAccessSettings => _currentProfile?.canAccessSettings ?? false;

  /// Whether the current user can manage profiles.
  bool get canManageProfiles => _currentProfile?.canManageProfiles ?? false;

  /// Whether the current user has access to all sources.
  bool get hasAllSourceAccess => _currentProfile?.hasAllSourceAccess ?? false;

  /// Gets the current user's role.
  UserRole get currentRole => _currentProfile?.role ?? UserRole.restricted;

  // ── DVR permission checks ───────────────────────────────────

  /// Whether the current user can view any recordings.
  bool get canViewRecordings => _currentProfile?.canViewRecordings ?? false;

  /// Whether the current user can schedule recordings.
  bool get canScheduleRecordings =>
      _currentProfile?.canScheduleRecordings ?? false;

  /// Gets the current user's DVR permission level.
  DvrPermission get dvrPermission =>
      _currentProfile?.dvrPermission ?? DvrPermission.none;

  /// Whether the current user can view a specific
  /// recording. Delegates to Rust backend.
  bool canViewRecording({
    required String? ownerProfileId,
    required bool isShared,
  }) {
    final profile = _currentProfile;
    if (profile == null) return false;

    return _backend.canViewRecording(
      _roleString(profile),
      ownerProfileId ?? '',
      profile.id,
    );
  }

  /// Whether the current user can delete a recording.
  /// Delegates to Rust backend.
  bool canDeleteRecording({
    required String? ownerProfileId,
    required bool isShared,
  }) {
    final profile = _currentProfile;
    if (profile == null) return false;

    return _backend.canDeleteRecording(
      _roleString(profile),
      ownerProfileId ?? '',
      profile.id,
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  /// Maps a [UserProfile] to the role string the
  /// Rust backend expects: `"admin"`, `"full_dvr"`,
  /// `"view_only"`, or `"none"`.
  static String _roleString(UserProfile profile) {
    if (profile.isAdmin) return 'admin';
    return switch (profile.dvrPermission) {
      DvrPermission.full => 'full_dvr',
      DvrPermission.viewOnly => 'view_only',
      DvrPermission.none => 'none',
    };
  }

  // ── Source access checks ────────────────────────────────────

  /// Checks if current user has access to a source.
  Future<bool> hasSourceAccess(String sourceId) async {
    final profile = _currentProfile;
    if (profile == null) return false;

    // Admins have access to all sources
    if (profile.isAdmin) return true;

    final service = _ref.read(sourceAccessServiceProvider.notifier);
    return service.hasAccess(profile.id, sourceId);
  }

  /// Gets all source IDs accessible to current user.
  /// Returns null if all sources are accessible (admin).
  Future<List<String>?> getAccessibleSources() async {
    final profile = _currentProfile;
    if (profile == null) return [];

    // Admins have access to all sources
    if (profile.isAdmin) return null;

    final service = _ref.read(sourceAccessServiceProvider.notifier);
    return service.getAccessibleSources(profile.id);
  }

  // ── Content rating checks ───────────────────────────────────

  /// Whether the current user can view content with a given rating.
  bool canViewRating(int rating) {
    final profile = _currentProfile;
    if (profile == null) return false;

    return rating <= profile.maxAllowedRating;
  }

  /// Gets the maximum allowed rating for current user.
  int get maxAllowedRating => _currentProfile?.maxAllowedRating ?? 0;

  // ── Action permission checks ────────────────────────────────

  /// Checks if user can perform an action requiring admin role.
  bool requiresAdmin() => isAdmin;

  /// Checks if user can perform an action requiring viewer or admin role.
  bool requiresViewer() => currentRole != UserRole.restricted;

  /// Checks if user can perform an action requiring full DVR access.
  bool requiresFullDvr() => dvrPermission == DvrPermission.full;
}

/// Provider for the permission guard.
final permissionGuardProvider = Provider<PermissionGuard>((ref) {
  return PermissionGuard(ref);
});

/// Provider for quick admin check.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(permissionGuardProvider).isAdmin;
});

/// Provider for settings access check.
final canAccessSettingsProvider = Provider<bool>((ref) {
  return ref.watch(permissionGuardProvider).canAccessSettings;
});

/// Provider for DVR scheduling check.
final canScheduleRecordingsProvider = Provider<bool>((ref) {
  return ref.watch(permissionGuardProvider).canScheduleRecordings;
});

/// Provider for DVR viewing check.
final canViewRecordingsProvider = Provider<bool>((ref) {
  return ref.watch(permissionGuardProvider).canViewRecordings;
});

/// Provider for profile management check.
final canManageProfilesProvider = Provider<bool>((ref) {
  return ref.watch(permissionGuardProvider).canManageProfiles;
});
