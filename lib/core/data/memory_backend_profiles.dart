part of 'memory_backend.dart';

/// Profile CRUD and source access methods
/// for [MemoryBackend].
mixin _MemoryProfilesMixin on _MemoryStorage {
  // ── Profiles ───────────────────────────────────

  Future<List<Map<String, dynamic>>> loadProfiles() async =>
      profiles.values.toList();

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    profiles[profile['id'] as String] = profile;
  }

  Future<void> deleteProfile(String id) async {
    profiles.remove(id);
    favorites.remove(id);
    vodFavorites.remove(id);
    sourceAccess.remove(id);
  }

  // ── Source Access ──────────────────────────────

  Future<List<String>> getSourceAccess(String profileId) async =>
      sourceAccess[profileId] ?? [];

  Future<void> grantSourceAccess(String profileId, String sourceId) async {
    final list = sourceAccess[profileId] ?? [];
    if (!list.contains(sourceId)) {
      list.add(sourceId);
    }
    sourceAccess[profileId] = list;
  }

  Future<void> revokeSourceAccess(String profileId, String sourceId) async {
    sourceAccess[profileId]?.remove(sourceId);
  }

  Future<void> setSourceAccess(String profileId, List<String> sourceIds) async {
    sourceAccess[profileId] = List.from(sourceIds);
  }

  Future<List<String>> getProfilesForSource(String sourceId) async {
    final result = <String>[];
    for (final e in sourceAccess.entries) {
      if (e.value.contains(sourceId)) {
        result.add(e.key);
      }
    }
    return result;
  }
}
