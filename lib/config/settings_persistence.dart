import 'dart:convert';

import '../core/data/cache_service.dart';
import '../core/domain/entities/playlist_source.dart';
import '../features/settings/domain/entities/remote_action.dart';
import 'settings_state.dart';

/// Handles persistence (load/save) of settings data
/// to the cache layer.
///
/// Extracted from [SettingsNotifier] to keep file sizes
/// manageable.
class SettingsPersistence {
  const SettingsPersistence(this._cache);

  final CacheService _cache;

  // ── Load helpers ──

  /// Loads persisted playlist sources.
  Future<List<PlaylistSource>> loadSources() async {
    final json = await _cache.getSetting(kSourcesKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => sourceFromJson(e as Map<String, dynamic>)).toList();
  }

  /// Loads persisted hidden category groups.
  Future<List<String>> loadHiddenGroups() async {
    final json = await _cache.getSetting(kHiddenGroupsKey);
    if (json == null) return [];
    return (jsonDecode(json) as List).cast<String>();
  }

  /// Loads a persisted [Set<String>] by key.
  Future<Set<String>> loadStringSet(String key) async {
    final json = await _cache.getSetting(key);
    if (json == null) return {};
    return (jsonDecode(json) as List).cast<String>().toSet();
  }

  /// Loads a persisted [Map<String, String>] by key.
  Future<Map<String, String>> loadStringMap(String key) async {
    final json = await _cache.getSetting(key);
    if (json == null) return {};
    return Map<String, String>.from(jsonDecode(json) as Map);
  }

  /// Loads persisted remote key mappings.
  Future<Map<int, RemoteAction>?> loadRemoteKeyMap() async {
    final json = await _cache.getSetting(kRemoteKeyMappingsKey);
    if (json == null) return null; // Use defaults.
    final raw = Map<String, String>.from(jsonDecode(json) as Map);
    return deserializeKeyMap(raw);
  }

  // ── Save helpers ──

  /// Persists a [Set<String>] by key.
  Future<void> saveStringSet(String key, Set<String> values) async {
    await _cache.setSetting(key, jsonEncode(values.toList()));
  }

  /// Persists a [Map<String, String>] by key.
  Future<void> saveStringMap(String key, Map<String, String> values) async {
    await _cache.setSetting(key, jsonEncode(values));
  }

  /// Persists remote key mappings.
  Future<void> saveRemoteKeyMap(Map<int, RemoteAction> map) async {
    await _cache.setSetting(
      kRemoteKeyMappingsKey,
      jsonEncode(serializeKeyMap(map)),
    );
  }

  /// Persists the playlist sources list.
  Future<void> saveSources(List<PlaylistSource> sources) async {
    final json = jsonEncode(sources.map(sourceToJson).toList());
    await _cache.setSetting(kSourcesKey, json);
  }

  // ── Serialization ──

  /// Converts a [PlaylistSource] to JSON map.
  Map<String, dynamic> sourceToJson(PlaylistSource s) => {
    'id': s.id,
    'name': s.name,
    'url': s.url,
    'type': s.type.name,
    'epgUrl': s.epgUrl,
    'userAgent': s.userAgent,
    'refreshIntervalMinutes': s.refreshIntervalMinutes,
    'username': s.username,
    'password': s.password,
    'accessToken': s.accessToken,
    'deviceId': s.deviceId,
    'userid': s.userId,
    'macAddress': s.macAddress,
  };

  /// Parses a [PlaylistSource] from a JSON map.
  PlaylistSource sourceFromJson(Map<String, dynamic> j) => PlaylistSource(
    id: j['id'] as String,
    name: j['name'] as String,
    url: j['url'] as String,
    type: PlaylistSourceType.values.byName(j['type'] as String),
    epgUrl: j['epgUrl'] as String?,
    userAgent: j['userAgent'] as String?,
    refreshIntervalMinutes: (j['refreshIntervalMinutes'] as int?) ?? 60,
    username: j['username'] as String?,
    password: j['password'] as String?,
    accessToken: j['accessToken'] as String?,
    deviceId: j['deviceId'] as String?,
    userId: j['userid'] as String?,
    macAddress: j['macAddress'] as String?,
  );
}
