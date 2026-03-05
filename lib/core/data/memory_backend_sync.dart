part of 'memory_backend.dart';

/// Backup, cloud merge, S3 crypto, Xtream URL
/// builders, and PIN hashing for [MemoryBackend].
mixin _MemorySyncMixin on _MemoryStorage {
  // ── Source Sync ──────────────────────────────────

  Future<bool> verifyXtreamCredentials({
    required String baseUrl,
    required String username,
    required String password,
    bool acceptInvalidCerts = false,
  }) async => true;

  Future<String> syncXtreamSource({
    required String baseUrl,
    required String username,
    required String password,
    required String sourceId,
    bool acceptInvalidCerts = false,
  }) async =>
      '{"channels_count":0,"channel_groups":[],"vod_count":0,"vod_categories":[],"epg_url":null}';

  Future<String> syncM3uSource({
    required String url,
    required String sourceId,
    bool acceptInvalidCerts = false,
  }) async =>
      '{"channels_count":0,"channel_groups":[],"vod_count":0,"vod_categories":[],"epg_url":null}';

  Future<bool> verifyStalkerPortal({
    required String baseUrl,
    required String macAddress,
    bool acceptInvalidCerts = false,
  }) async => true;

  Future<String> syncStalkerSource({
    required String baseUrl,
    required String macAddress,
    required String sourceId,
    bool acceptInvalidCerts = false,
  }) async =>
      '{"channels_count":0,"channel_groups":[],"vod_count":0,"vod_categories":[],"epg_url":null}';

  Stream<String> subscribeSyncProgress() => const Stream.empty();

  // ── Backup ─────────────────────────────────────

  Future<String> exportBackup() async => '{}';

  Future<Map<String, dynamic>> importBackup(String json) async => {};

  // ── S3 Crypto ──────────────────────────────────

  Future<String> signS3Request({
    required String method,
    required String path,
    required int nowUtcMs,
    required String host,
    required String region,
    required String accessKey,
    required String secretKey,
    String? extraHeadersJson,
  }) async => '{}';

  Future<String> generatePresignedUrl({
    required String endpoint,
    required String bucket,
    required String objectKey,
    required String region,
    required String accessKey,
    required String secretKey,
    required int expirySecs,
    required int nowUtcMs,
  }) async => '';

  // ── Cloud Merge ────────────────────────────────

  Future<String> mergeCloudBackups(
    String localJson,
    String cloudJson,
    String currentDeviceId,
  ) async => _MemoryCloudMerge.merge(localJson, cloudJson, currentDeviceId);

  // ── PIN Hashing ────────────────────────────────

  Future<String> hashPin(String pin) async {
    final bytes = utf8.encode(pin);
    var hash = 0x811c9dc5;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(64, '0');
  }

  Future<bool> verifyPin(String inputPin, String storedHash) async {
    final computed = await hashPin(inputPin);
    return computed == storedHash;
  }

  bool isHashedPin(String value) =>
      value.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);

  // ── Xtream URL Builders ────────────────────────

  /// Delegates to shared [dartBuildXtreamActionUrl].
  String buildXtreamActionUrl({
    required String baseUrl,
    required String username,
    required String password,
    required String action,
    String? paramsJson,
  }) => dartBuildXtreamActionUrl(
    baseUrl: baseUrl,
    username: username,
    password: password,
    action: action,
    paramsJson: paramsJson,
  );

  /// Delegates to shared [dartBuildXtreamStreamUrl].
  String buildXtreamStreamUrl({
    required String baseUrl,
    required String username,
    required String password,
    required int streamId,
    required String streamType,
    required String extension,
  }) => dartBuildXtreamStreamUrl(
    baseUrl: baseUrl,
    username: username,
    password: password,
    streamId: streamId,
    streamType: streamType,
    extension: extension,
  );

  /// Delegates to shared [dartBuildXtreamCatchupUrl].
  String buildXtreamCatchupUrl({
    required String baseUrl,
    required String username,
    required String password,
    required int streamId,
    required int startUtc,
    required int durationMinutes,
  }) => dartBuildXtreamCatchupUrl(
    baseUrl: baseUrl,
    username: username,
    password: password,
    streamId: streamId,
    startUtc: startUtc,
    durationMinutes: durationMinutes,
  );
}

// ── Cloud Merge helper ──────────────────────────

/// Pure-Dart cloud backup merge for
/// [MemoryBackend]. Replicates the Rust
/// algorithm so unit tests run without FFI.
class _MemoryCloudMerge {
  _MemoryCloudMerge._();

  static String merge(
    String localJson,
    String cloudJson,
    String currentDeviceId,
  ) {
    final local = json.decode(localJson) as Map<String, dynamic>;
    final cloud = json.decode(cloudJson) as Map<String, dynamic>;
    final localTime = DateTime.tryParse(local['exportedAt'] as String? ?? '');
    final cloudTime = DateTime.tryParse(cloud['exportedAt'] as String? ?? '');
    final localIsNewer =
        localTime != null && cloudTime != null && localTime.isAfter(cloudTime);
    final merged = <String, dynamic>{
      'version': _max(
        local['version'] as int? ?? 1,
        cloud['version'] as int? ?? 1,
      ),
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profiles': _mergeProfiles(
        local['profiles'] as List<dynamic>? ?? [],
        cloud['profiles'] as List<dynamic>? ?? [],
      ),
      'favorites': _mergeSets(
        local['favorites'] as Map<String, dynamic>? ?? {},
        cloud['favorites'] as Map<String, dynamic>? ?? {},
      ),
      'channelOrders': _mergeById(
        local['channelOrders'] as List<dynamic>? ?? [],
        cloud['channelOrders'] as List<dynamic>? ?? [],
        _channelOrderKey,
        preferLocal: true,
      ),
      'sourceAccess': _mergeSets(
        local['sourceAccess'] as Map<String, dynamic>? ?? {},
        cloud['sourceAccess'] as Map<String, dynamic>? ?? {},
      ),
      'settings': _mergeSettings(
        local['settings'] as Map<String, dynamic>? ?? {},
        cloud['settings'] as Map<String, dynamic>? ?? {},
        localIsNewer: localIsNewer,
      ),
      'watchHistory': _mergeWatchHistory(
        local['watchHistory'] as List<dynamic>? ?? [],
        cloud['watchHistory'] as List<dynamic>? ?? [],
      ),
      'recordings': _mergeById(
        local['recordings'] as List<dynamic>? ?? [],
        cloud['recordings'] as List<dynamic>? ?? [],
        _recordingKey,
        preferLocal: localIsNewer,
      ),
      'sources': _mergeSources(
        local['sources'] as List<dynamic>? ?? [],
        cloud['sources'] as List<dynamic>? ?? [],
      ),
    };
    return json.encode(merged);
  }

  static int _max(int a, int b) => a > b ? a : b;

  static List<dynamic> _mergeProfiles(
    List<dynamic> local,
    List<dynamic> cloud,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final item in cloud) {
      final m = item as Map<String, dynamic>;
      byId[m['id'] as String] = m;
    }
    for (final item in local) {
      final m = item as Map<String, dynamic>;
      byId[m['id'] as String] = m;
    }
    return byId.values.toList();
  }

  /// Union-merge for favorites and sourceAccess.
  static Map<String, dynamic> _mergeSets(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) {
    final result = <String, dynamic>{};
    for (final key in {...local.keys, ...cloud.keys}) {
      final l = (local[key] as List<dynamic>?)?.cast<String>().toSet() ?? {};
      final c = (cloud[key] as List<dynamic>?)?.cast<String>().toSet() ?? {};
      result[key] = l.union(c).toList();
    }
    return result;
  }

  static Map<String, dynamic> _mergeSettings(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud, {
    required bool localIsNewer,
  }) {
    // Canonical key set — mirrors Rust SYNC_META_KEYS in
    // rust/crates/crispy-core/src/algorithms/cloud_sync/merge.rs.
    const syncMetaKeys = {kSyncLastTimeKey, kSyncLocalModifiedTimeKey};
    final base = localIsNewer ? cloud : local;
    final over = localIsNewer ? local : cloud;
    final result = <String, dynamic>{...base, ...over};
    for (final key in syncMetaKeys) {
      if (local.containsKey(key)) {
        result[key] = local[key];
      } else {
        result.remove(key);
      }
    }
    return result;
  }

  static List<dynamic> _mergeWatchHistory(
    List<dynamic> local,
    List<dynamic> cloud,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final item in cloud) {
      final m = Map<String, dynamic>.from(item as Map);
      byId[m['id'] as String] = m;
    }
    for (final item in local) {
      final m = Map<String, dynamic>.from(item as Map);
      final id = m['id'] as String;
      final existing = byId[id];
      if (existing == null) {
        byId[id] = m;
        continue;
      }
      final lp = m['positionMs'] as int? ?? 0;
      final cp = existing['positionMs'] as int? ?? 0;
      final maxPos = lp > cp ? lp : cp;
      final lt = DateTime.tryParse(m['lastWatched'] as String? ?? '');
      final ct = DateTime.tryParse(existing['lastWatched'] as String? ?? '');
      if (lt != null && ct != null && lt.isAfter(ct)) {
        byId[id] = m;
      }
      byId[id]!['positionMs'] = maxPos;
    }
    return byId.values.toList();
  }

  static List<dynamic> _mergeSources(List<dynamic> local, List<dynamic> cloud) {
    final seen = <String>{};
    final result = <dynamic>[];
    for (final item in local) {
      final m = item as Map<String, dynamic>;
      if (seen.add(_sourceKey(m))) result.add(m);
    }
    for (final item in cloud) {
      final m = item as Map<String, dynamic>;
      if (seen.add(_sourceKey(m))) result.add(m);
    }
    return result;
  }

  static List<dynamic> _mergeById(
    List<dynamic> local,
    List<dynamic> cloud,
    String Function(Map<String, dynamic>) keyFn, {
    required bool preferLocal,
  }) {
    final byKey = <String, Map<String, dynamic>>{};
    final base = preferLocal ? cloud : local;
    final pref = preferLocal ? local : cloud;
    for (final item in base) {
      final m = item as Map<String, dynamic>;
      byKey[keyFn(m)] = m;
    }
    for (final item in pref) {
      final m = item as Map<String, dynamic>;
      byKey[keyFn(m)] = m;
    }
    return byKey.values.toList();
  }

  static String _channelOrderKey(Map<String, dynamic> m) =>
      '${m['profileId']}_${m['groupName']}_'
      '${m['channelId']}';

  static String _recordingKey(Map<String, dynamic> m) =>
      m['id'] as String? ?? '';

  static String _sourceKey(Map<String, dynamic> m) {
    final name = m['name'] as String? ?? '';
    final url = m['url'] as String? ?? '';
    return '${name}_$url';
  }
}
