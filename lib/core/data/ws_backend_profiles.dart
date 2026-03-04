part of 'ws_backend.dart';

/// Profile-related WebSocket commands.
mixin _WsProfilesMixin on _WsBackendBase {
  // ── Profiles ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadProfiles() async {
    final data = await _send('loadProfiles');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveProfile(Map<String, dynamic> profile) =>
      _send('saveProfile', {'profile': profile});

  Future<void> deleteProfile(String id) => _send('deleteProfile', {'id': id});

  // ── Source Access ────────────────────────────────

  Future<List<String>> getSourceAccess(String profileId) async {
    final data = await _send('getSourceAccess', {'profileId': profileId});
    return (data as List).cast<String>();
  }

  Future<void> grantSourceAccess(String profileId, String sourceId) => _send(
    'grantSourceAccess',
    {'profileId': profileId, 'sourceId': sourceId},
  );

  Future<void> revokeSourceAccess(String profileId, String sourceId) => _send(
    'revokeSourceAccess',
    {'profileId': profileId, 'sourceId': sourceId},
  );

  Future<void> setSourceAccess(String profileId, List<String> sourceIds) =>
      _send('setSourceAccess', {
        'profileId': profileId,
        'sourceIds': sourceIds,
      });

  // ── Phase 8: Profile Service ─────────────────────

  Future<List<String>> getProfilesForSource(String sourceId) async {
    final data = await _send('getProfilesForSource', {'sourceId': sourceId});
    return (data as List).cast<String>();
  }
}
