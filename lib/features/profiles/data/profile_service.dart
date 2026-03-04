import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../domain/entities/user_profile.dart';
import '../domain/enums/dvr_permission.dart';
import '../domain/enums/user_role.dart';

// FE-PM-02: ProfileType imported via user_profile.dart barrel.

/// Manages user profiles — CRUD, switching, PIN validation.
///
/// Backed by Drift (SQLite) persistence via [CacheService].
class ProfileService extends AsyncNotifier<ProfileState> {
  late CacheService _cache;
  late CrispyBackend _backend;

  @override
  Future<ProfileState> build() async {
    _cache = ref.read(cacheServiceProvider);
    _backend = ref.read(crispyBackendProvider);
    var profiles = await _cache.loadProfiles();

    if (profiles.isEmpty) {
      // Initialize with default profile if none exist.
      // First profile is always admin.
      const defaultProfile = UserProfile(
        id: 'default',
        name: 'Default',
        avatarIndex: 0,
        isActive: true,
        pinVersion: 1,
        role: UserRole.admin,
        dvrPermission: DvrPermission.full,
      );
      await _cache.saveProfile(defaultProfile);
      return const ProfileState(
        profiles: [defaultProfile],
        activeProfileId: 'default',
      );
    }

    // Auto-migrate plaintext PINs to SHA-256.
    profiles = await _migratePlaintextPins(profiles);

    // Return loaded profiles.
    // By default, set the first profile as 'active' in state,
    // but the router will verify if explicit selection happened.
    return ProfileState(profiles: profiles, activeProfileId: profiles.first.id);
  }

  /// Migrates profiles with plaintext PINs (pinVersion 0) to hashed PINs.
  Future<List<UserProfile>> _migratePlaintextPins(
    List<UserProfile> profiles,
  ) async {
    final migrated = <UserProfile>[];

    for (final profile in profiles) {
      if (profile.hasPIN && profile.pinVersion == 0) {
        // Plaintext PIN detected — hash and upgrade version.
        final hashedPin = await _backend.hashPin(profile.pin!);
        final updated = profile.copyWith(pin: hashedPin, pinVersion: 1);
        await _cache.saveProfile(updated);
        migrated.add(updated);
      } else {
        migrated.add(profile);
      }
    }

    return migrated;
  }

  /// Creates a new profile and persists it.
  Future<void> addProfile({
    required String name,
    int avatarIndex = 0,
    String? pin,
    bool isChild = false,
    // FE-PM-10: guest profiles have no PIN and no watch history persistence.
    bool isGuest = false,
    int maxAllowedRating = 4,
    UserRole role = UserRole.viewer,
    DvrPermission dvrPermission = DvrPermission.full,
    int? dvrQuotaMB,
    int? accentColorValue,
    String? preferredAudioLanguage,
    String? preferredSubtitleLanguage,
    bool subtitleEnabledByDefault = false,
    // FE-PM-02: profile type (standard or kids).
    ProfileType profileType = ProfileType.standard,
  }) async {
    final id = 'profile_${DateTime.now().millisecondsSinceEpoch}';

    // Guest profiles never have a PIN.
    final effectivePin = isGuest ? null : pin;

    // Hash PIN if provided.
    final hashedPin =
        effectivePin != null ? await _backend.hashPin(effectivePin) : null;

    // FE-PM-02: kids profiles always cap at PG (index 1).
    final effectiveMaxRating =
        profileType == ProfileType.kids ? 1 : maxAllowedRating;

    final profile = UserProfile(
      id: id,
      name: name,
      avatarIndex: avatarIndex,
      pin: hashedPin,
      pinVersion: 1, // Always use hashed PINs for new profiles
      isChild: isChild || profileType == ProfileType.kids,
      isGuest: isGuest,
      maxAllowedRating: effectiveMaxRating,
      role: role,
      dvrPermission: dvrPermission,
      dvrQuotaMB: dvrQuotaMB,
      accentColorValue: accentColorValue,
      preferredAudioLanguage: preferredAudioLanguage,
      preferredSubtitleLanguage: preferredSubtitleLanguage,
      subtitleEnabledByDefault: subtitleEnabledByDefault,
      // FE-PM-02
      profileType: profileType,
    );

    await _cache.saveProfile(profile);

    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncData(
      currentState.copyWith(profiles: [...currentState.profiles, profile]),
    );
  }

  /// Creates a guest profile with a generated name and no PIN (FE-PM-10).
  ///
  /// Guest profiles use avatar index 9 (star icon) and a grey-toned
  /// display. Watch history is never persisted for guest profiles.
  Future<void> addGuestProfile() async {
    await addProfile(
      name: 'Guest',
      avatarIndex: 9,
      isGuest: true,
      role: UserRole.viewer,
      dvrPermission: DvrPermission.none,
    );
  }

  /// Removes a profile by ID. Cannot remove the last profile.
  Future<void> removeProfile(String id) async {
    final currentState = state.value;
    if (currentState == null) return;
    final current = currentState.profiles;
    if (current.length <= 1) return;

    await _cache.deleteProfile(id);

    final updated = current.where((p) => p.id != id).toList();
    final newActiveId =
        currentState.activeProfileId == id
            ? updated.first.id
            : currentState.activeProfileId;

    state = AsyncData(
      currentState.copyWith(profiles: updated, activeProfileId: newActiveId),
    );
  }

  /// Switches active profile. Validates PIN if set.
  Future<bool> switchProfile(String id, {String? pin}) async {
    final current = state.value?.profiles ?? [];
    final index = current.indexWhere((p) => p.id == id);
    if (index == -1) {
      // Profile not found — log warning and return false gracefully.
      debugPrint('switchProfile: profile $id not found');
      return false;
    }
    final profile = current[index];

    // Validate PIN if required.
    if (profile.hasPIN) {
      if (pin == null) return false;

      final isValid = await _backend.verifyPin(pin, profile.pin!);

      if (!isValid) return false;
    }

    final updated =
        current.map((p) => p.copyWith(isActive: p.id == id)).toList();

    // We don't persist 'isActive' to DB here, as it's
    // a runtime state for now.

    final currentState = state.value;
    if (currentState == null) return false;
    state = AsyncData(
      currentState.copyWith(profiles: updated, activeProfileId: id),
    );
    return true;
  }

  /// Updates a profile's display settings.
  Future<void> updateProfile(
    String id, {
    String? name,
    int? avatarIndex,
    String? pin,
    bool? isChild,
    int? maxAllowedRating,
    UserRole? role,
    DvrPermission? dvrPermission,
    int? dvrQuotaMB,
    int? accentColorValue,
    String? preferredAudioLanguage,
    String? preferredSubtitleLanguage,
    bool? subtitleEnabledByDefault,
    bool clearPin = false,
    bool clearDvrQuota = false,
    bool clearAccentColor = false,
    bool clearAudioLanguage = false,
    bool clearSubtitleLanguage = false,
  }) async {
    final current = state.value?.profiles ?? [];
    final index = current.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final oldProfile = current[index];

    // Hash new PIN if provided.
    final hashedPin = pin != null ? await _backend.hashPin(pin) : null;

    final newProfile = oldProfile.copyWith(
      name: name,
      avatarIndex: avatarIndex,
      pin: hashedPin,
      pinVersion: hashedPin != null ? 1 : null,
      isChild: isChild,
      maxAllowedRating: maxAllowedRating,
      role: role,
      dvrPermission: dvrPermission,
      dvrQuotaMB: dvrQuotaMB,
      accentColorValue: accentColorValue,
      preferredAudioLanguage: preferredAudioLanguage,
      preferredSubtitleLanguage: preferredSubtitleLanguage,
      subtitleEnabledByDefault: subtitleEnabledByDefault,
      clearPin: clearPin,
      clearDvrQuota: clearDvrQuota,
      clearAccentColor: clearAccentColor,
      clearAudioLanguage: clearAudioLanguage,
      clearSubtitleLanguage: clearSubtitleLanguage,
    );

    await _cache.saveProfile(newProfile);

    final updated = List<UserProfile>.from(current);
    updated[index] = newProfile;

    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncData(currentState.copyWith(profiles: updated));
  }

  /// Updates a profile's role. Only admins can do this.
  ///
  /// Returns true if successful, false if permission denied.
  Future<bool> updateProfileRole(String targetId, UserRole newRole) async {
    final currentProfile = state.value?.activeProfile;
    if (currentProfile == null || !currentProfile.isAdmin) {
      return false;
    }

    // Prevent demoting the last admin
    final current = state.value?.profiles ?? [];
    final adminCount = current.where((p) => p.role == UserRole.admin).length;
    final targetProfile = current.firstWhere(
      (p) => p.id == targetId,
      orElse: () => throw StateError('Profile not found'),
    );

    if (targetProfile.isAdmin && newRole != UserRole.admin && adminCount <= 1) {
      return false; // Cannot demote last admin
    }

    await updateProfile(targetId, role: newRole);
    return true;
  }

  /// Updates a profile's DVR permission. Only admins can do this.
  Future<bool> updateProfileDvrPermission(
    String targetId,
    DvrPermission permission,
  ) async {
    final currentProfile = state.value?.activeProfile;
    if (currentProfile == null || !currentProfile.isAdmin) {
      return false;
    }

    await updateProfile(targetId, dvrPermission: permission);
    return true;
  }

  /// Updates the accent color for a profile.
  ///
  /// [accentColorValue] is a 32-bit ARGB integer; pass null to clear.
  /// Any profile can update its own accent color.
  Future<void> updateProfileAccentColor(
    String profileId,
    int? accentColorValue,
  ) async {
    await updateProfile(
      profileId,
      accentColorValue: accentColorValue,
      clearAccentColor: accentColorValue == null,
    );
  }

  /// Updates language and subtitle preferences for a profile (FE-PM-07).
  ///
  /// Pass null for a language to clear the preference (no override).
  Future<void> updateProfileLanguagePrefs(
    String profileId, {
    String? preferredAudioLanguage,
    bool clearAudioLanguage = false,
    String? preferredSubtitleLanguage,
    bool clearSubtitleLanguage = false,
    bool? subtitleEnabledByDefault,
  }) async {
    await updateProfile(
      profileId,
      preferredAudioLanguage: preferredAudioLanguage,
      preferredSubtitleLanguage: preferredSubtitleLanguage,
      subtitleEnabledByDefault: subtitleEnabledByDefault,
      clearAudioLanguage: clearAudioLanguage,
      clearSubtitleLanguage: clearSubtitleLanguage,
    );
  }

  /// Updates a profile's DVR quota. Only admins can do this.
  Future<bool> updateProfileDvrQuota(String targetId, int? quotaMB) async {
    final currentProfile = state.value?.activeProfile;
    if (currentProfile == null || !currentProfile.isAdmin) {
      return false;
    }

    await updateProfile(
      targetId,
      dvrQuotaMB: quotaMB,
      clearDvrQuota: quotaMB == null,
    );
    return true;
  }

  /// FE-PS-07: Reorders profiles by moving the item at [oldIndex] to [newIndex].
  ///
  /// Uses [ReorderableListView] conventions: call after the widget fires
  /// `onReorder(oldIndex, newIndex)`. Persists the new order by re-saving
  /// each profile so that [loadProfiles] returns them in order next launch.
  Future<void> reorderProfiles(int oldIndex, int newIndex) async {
    final currentState = state.value;
    if (currentState == null) return;

    final list = List<UserProfile>.from(currentState.profiles);
    // ReorderableListView passes newIndex after removal — adjust.
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final item = list.removeAt(oldIndex);
    list.insert(adjusted, item);

    // Persist updated order.
    for (final profile in list) {
      await _cache.saveProfile(profile);
    }

    state = AsyncData(currentState.copyWith(profiles: list));
  }

  /// Checks if the current user is an admin.
  bool get isCurrentUserAdmin => state.value?.activeProfile?.isAdmin ?? false;

  /// Gets all admin profiles.
  List<UserProfile> get adminProfiles =>
      state.value?.profiles.where((p) => p.isAdmin).toList() ?? [];
}

/// Profiles state.
class ProfileState {
  const ProfileState({
    this.profiles = const [],
    this.activeProfileId = 'default',
  });

  final List<UserProfile> profiles;
  final String activeProfileId;

  UserProfile? get activeProfile =>
      profiles.isEmpty
          ? null
          : profiles.firstWhere(
            (p) => p.id == activeProfileId,
            orElse: () => profiles.first,
          );

  ProfileState copyWith({
    List<UserProfile>? profiles,
    String? activeProfileId,
  }) {
    return ProfileState(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
    );
  }
}

/// Global profile service provider.
final profileServiceProvider =
    AsyncNotifierProvider<ProfileService, ProfileState>(ProfileService.new);
