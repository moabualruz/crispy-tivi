part of 'ws_backend.dart';

/// Sync, backup, and cloud WebSocket commands.
mixin _WsSyncMixin on _WsBackendBase {
  // ── Sync Metadata ────────────────────────────────

  Future<int?> getLastSyncTime(String sourceId) async {
    final data = await _send('getLastSyncTime', {'sourceId': sourceId});
    if (data == null) return null;
    return (data as num).toInt();
  }

  Future<void> setLastSyncTime(String sourceId, int timestamp) =>
      _send('setLastSyncTime', {'sourceId': sourceId, 'timestamp': timestamp});

  // ── Source Sync ─────────────────────────────────

  Future<bool> verifyXtreamCredentials({
    required String baseUrl,
    required String username,
    required String password,
    bool acceptInvalidCerts = false,
  }) async {
    final data = await _send('verifyXtreamCredentials', {
      'baseUrl': baseUrl,
      'username': username,
      'password': password,
      'acceptInvalidCerts': acceptInvalidCerts,
    });
    return data as bool;
  }

  Future<String> syncXtreamSource({
    required String baseUrl,
    required String username,
    required String password,
    required String sourceId,
    bool acceptInvalidCerts = false,
  }) async {
    final data = await _send('syncXtreamSource', {
      'baseUrl': baseUrl,
      'username': username,
      'password': password,
      'sourceId': sourceId,
      'acceptInvalidCerts': acceptInvalidCerts,
    });
    return jsonEncode(data);
  }

  Future<String> syncM3uSource({
    required String url,
    required String sourceId,
    bool acceptInvalidCerts = false,
  }) async {
    final data = await _send('syncM3uSource', {
      'url': url,
      'sourceId': sourceId,
      'acceptInvalidCerts': acceptInvalidCerts,
    });
    return jsonEncode(data);
  }

  Future<bool> verifyM3uUrl({
    required String url,
    bool acceptInvalidCerts = false,
  }) async {
    final data = await _send('verifyM3uUrl', {
      'url': url,
      'acceptInvalidCerts': acceptInvalidCerts,
    });
    return data as bool;
  }

  Future<bool> verifyStalkerPortal({
    required String baseUrl,
    required String macAddress,
    bool acceptInvalidCerts = false,
  }) async {
    final data = await _send('verifyStalkerPortal', {
      'baseUrl': baseUrl,
      'macAddress': macAddress,
      'acceptInvalidCerts': acceptInvalidCerts,
    });
    return data as bool;
  }

  Future<String> syncStalkerSource({
    required String baseUrl,
    required String macAddress,
    required String sourceId,
    bool acceptInvalidCerts = false,
  }) async {
    final data = await _send('syncStalkerSource', {
      'baseUrl': baseUrl,
      'macAddress': macAddress,
      'sourceId': sourceId,
      'acceptInvalidCerts': acceptInvalidCerts,
    });
    return jsonEncode(data);
  }

  // Web target: progress events are not streamed via WS yet.
  Stream<String> subscribeSyncProgress() => const Stream.empty();

  // ── Backup ───────────────────────────────────────

  Future<String> exportBackup() async {
    final data = await _send('exportBackup');
    return data as String;
  }

  Future<Map<String, dynamic>> importBackup(String json) async {
    final data = await _send('importBackup', {'json': json});
    return data as Map<String, dynamic>;
  }

  // ── S3 Crypto ────────────────────────────────────

  Future<String> signS3Request({
    required String method,
    required String path,
    required int nowUtcMs,
    required String host,
    required String region,
    required String accessKey,
    required String secretKey,
    String? extraHeadersJson,
  }) async {
    final data = await _send('signS3Request', {
      'method': method,
      'path': path,
      'nowUtcMs': nowUtcMs,
      'host': host,
      'region': region,
      'accessKey': accessKey,
      'secretKey': secretKey,
      if (extraHeadersJson != null) 'extraHeadersJson': extraHeadersJson,
    });
    return data as String;
  }

  Future<String> generatePresignedUrl({
    required String endpoint,
    required String bucket,
    required String objectKey,
    required String region,
    required String accessKey,
    required String secretKey,
    required int expirySecs,
    required int nowUtcMs,
  }) async {
    final data = await _send('generatePresignedUrl', {
      'endpoint': endpoint,
      'bucket': bucket,
      'objectKey': objectKey,
      'region': region,
      'accessKey': accessKey,
      'secretKey': secretKey,
      'expirySecs': expirySecs,
      'nowUtcMs': nowUtcMs,
    });
    return data as String;
  }

  // ── Cloud Merge ──────────────────────────────────

  Future<String> mergeCloudBackups(
    String localJson,
    String cloudJson,
    String currentDeviceId,
  ) async {
    final data = await _send('mergeCloudBackups', {
      'localJson': localJson,
      'cloudJson': cloudJson,
      'currentDeviceId': currentDeviceId,
    });
    return data as String;
  }

  // ── S3 Parser ──────────────────────────────────

  Future<String> parseS3ListObjects(String xml) async {
    final data = await _send('parseS3ListObjects', {'xml': xml});
    return data as String;
  }

  // ── Cloud Sync Direction ───────────────────────

  String determineSyncDirection(
    int localMs,
    int cloudMs,
    int lastSyncMs,
    String localDevice,
    String cloudDevice,
  ) {
    // Sync — local Dart fallback (matches Rust logic).
    if (cloudMs == 0) {
      if (localMs == 0) return 'no_change';
      return 'upload';
    }
    if (localMs == 0) return 'download';
    if ((localMs - cloudMs).abs() <= 5000) return 'no_change';
    if (cloudDevice.isNotEmpty &&
        cloudDevice != localDevice &&
        localMs > lastSyncMs) {
      return 'conflict';
    }
    return localMs > cloudMs ? 'upload' : 'download';
  }
}
