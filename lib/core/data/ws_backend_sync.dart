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
