part of 'ffi_backend.dart';

/// Profile-related FFI calls.
mixin _FfiProfilesMixin on _FfiBackendBase {
  // ── Profiles ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadProfiles() async {
    final json = await rust_api.loadProfiles();
    return _decodeJsonList(json);
  }

  Future<void> saveProfile(Map<String, dynamic> profile) =>
      rust_api.saveProfile(json: jsonEncode(profile));

  Future<void> deleteProfile(String id) => rust_api.deleteProfile(id: id);

  // ── Source Access ────────────────────────────────

  Future<List<String>> getSourceAccess(String profileId) =>
      rust_api.getSourceAccess(profileId: profileId);

  Future<void> grantSourceAccess(String profileId, String sourceId) =>
      rust_api.grantSourceAccess(profileId: profileId, sourceId: sourceId);

  Future<void> revokeSourceAccess(String profileId, String sourceId) =>
      rust_api.revokeSourceAccess(profileId: profileId, sourceId: sourceId);

  Future<void> setSourceAccess(String profileId, List<String> sourceIds) =>
      rust_api.setSourceAccess(profileId: profileId, sourceIds: sourceIds);

  // ── Phase 8: Profile Service ─────────────────────

  Future<List<String>> getProfilesForSource(String sourceId) =>
      rust_api.getProfilesForSource(sourceId: sourceId);
}
