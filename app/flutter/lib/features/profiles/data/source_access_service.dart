import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../domain/enums/user_role.dart';
import 'profile_service.dart';

/// Manages profile-to-source access mappings.
///
/// Admins have implicit access to all sources.
/// Viewers and restricted profiles need explicit grants.
class SourceAccessService extends AsyncNotifier<SourceAccessState> {
  late CacheService _cache;

  @override
  Future<SourceAccessState> build() async {
    _cache = ref.read(cacheServiceProvider);
    return const SourceAccessState();
  }

  /// Checks if a profile has access to a source.
  ///
  /// Returns true if:
  /// - Profile is admin (implicit full access)
  /// - Profile has explicit source grant
  Future<bool> hasAccess(String profileId, String sourceId) async {
    final profileState = ref.read(profileServiceProvider).value;
    if (profileState == null) return false;

    final profile = profileState.profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => throw StateError('Profile not found'),
    );

    // Admins have access to all sources
    if (profile.role == UserRole.admin) return true;

    // Check explicit grants
    final grants = await _cache.getSourceAccess(profileId);
    return grants.contains(sourceId);
  }

  /// Gets all source IDs accessible to a profile.
  ///
  /// For admins, returns null (meaning all sources).
  /// For others, returns the list of granted source IDs.
  Future<List<String>?> getAccessibleSources(String profileId) async {
    final profileState = ref.read(profileServiceProvider).value;
    if (profileState == null) return [];

    final profile = profileState.profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => throw StateError('Profile not found'),
    );

    // Admins have access to all sources
    if (profile.role == UserRole.admin) return null;

    return _cache.getSourceAccess(profileId);
  }

  /// Grants a profile access to a source.
  ///
  /// Only admins can grant access.
  Future<bool> grantAccess(
    String profileId,
    String sourceId, {
    required String requestingProfileId,
  }) async {
    if (!await _isAdmin(requestingProfileId)) return false;

    await _cache.grantSourceAccess(profileId, sourceId);
    _notifyUpdate();
    return true;
  }

  /// Revokes a profile's access to a source.
  ///
  /// Only admins can revoke access.
  Future<bool> revokeAccess(
    String profileId,
    String sourceId, {
    required String requestingProfileId,
  }) async {
    if (!await _isAdmin(requestingProfileId)) return false;

    await _cache.revokeSourceAccess(profileId, sourceId);
    _notifyUpdate();
    return true;
  }

  /// Sets complete source access for a profile.
  ///
  /// Replaces all existing grants with the new list.
  /// Only admins can set access.
  Future<bool> setAccess(
    String profileId,
    List<String> sourceIds, {
    required String requestingProfileId,
  }) async {
    if (!await _isAdmin(requestingProfileId)) return false;

    await _cache.setSourceAccess(profileId, sourceIds);
    _notifyUpdate();
    return true;
  }

  /// Gets all profiles with access to a specific source.
  Future<List<String>> getProfilesWithAccess(String sourceId) async {
    final profileState = ref.read(profileServiceProvider).value;
    if (profileState == null) return [];

    // Start with explicitly granted profiles
    final explicitGrants = await _cache.getProfilesWithSourceAccess(sourceId);

    // Add admins (they have implicit access)
    final adminIds =
        profileState.profiles
            .where((p) => p.role == UserRole.admin)
            .map((p) => p.id)
            .toList();

    return {...explicitGrants, ...adminIds}.toList();
  }

  /// Checks if a profile is admin.
  Future<bool> _isAdmin(String profileId) async {
    final profileState = ref.read(profileServiceProvider).value;
    if (profileState == null) return false;

    final profile = profileState.profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => throw StateError('Profile not found'),
    );

    return profile.role == UserRole.admin;
  }

  void _notifyUpdate() {
    state = AsyncData(SourceAccessState(lastUpdate: DateTime.now()));
  }
}

/// State for source access tracking.
class SourceAccessState {
  const SourceAccessState({this.lastUpdate});

  /// Last update timestamp for cache invalidation.
  final DateTime? lastUpdate;
}

/// Provider for source access service.
final sourceAccessServiceProvider =
    AsyncNotifierProvider<SourceAccessService, SourceAccessState>(
      SourceAccessService.new,
    );

/// Provider that checks if current profile has access to a source.
final hasSourceAccessProvider = FutureProvider.family<bool, String>((
  ref,
  sourceId,
) async {
  final profileState = ref.watch(profileServiceProvider).value;
  if (profileState == null) return false;

  final service = ref.read(sourceAccessServiceProvider.notifier);
  return service.hasAccess(profileState.activeProfileId, sourceId);
});

/// Provider for accessible source IDs for current profile.
///
/// Returns null if all sources are accessible (admin).
final accessibleSourcesProvider = FutureProvider<List<String>?>((ref) async {
  final profileState = ref.watch(profileServiceProvider).value;
  if (profileState == null) return [];

  final service = ref.read(sourceAccessServiceProvider.notifier);
  return service.getAccessibleSources(profileState.activeProfileId);
});
