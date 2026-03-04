part of 'ffi_backend.dart';

/// Sync, backup, and cloud FFI calls.
mixin _FfiSyncMixin on _FfiBackendBase {
  // ── Sync Metadata ────────────────────────────────

  Future<int?> getLastSyncTime(String sourceId) async {
    final dynamic result = await rust_api.getLastSyncTime(sourceId: sourceId);
    if (result == null) return null;
    return result is BigInt ? result.toInt() : (result as int);
  }

  Future<void> setLastSyncTime(String sourceId, int timestamp) =>
      rust_api.setLastSyncTime(
        sourceId: sourceId,
        timestamp: PlatformInt64Util.from(timestamp),
      );

  // ── Backup ───────────────────────────────────────

  Future<String> exportBackup() => rust_api.exportBackup();

  Future<Map<String, dynamic>> importBackup(String json) async {
    final result = await rust_api.importBackup(json: json);
    return jsonDecode(result) as Map<String, dynamic>;
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
  }) => rust_api.signS3Request(
    method: method,
    path: path,
    nowUtcMs: PlatformInt64Util.from(nowUtcMs),
    host: host,
    region: region,
    accessKey: accessKey,
    secretKey: secretKey,
    extraHeadersJson: extraHeadersJson,
  );

  Future<String> generatePresignedUrl({
    required String endpoint,
    required String bucket,
    required String objectKey,
    required String region,
    required String accessKey,
    required String secretKey,
    required int expirySecs,
    required int nowUtcMs,
  }) => rust_api.generatePresignedUrl(
    endpoint: endpoint,
    bucket: bucket,
    objectKey: objectKey,
    region: region,
    accessKey: accessKey,
    secretKey: secretKey,
    expirySecs: PlatformInt64Util.from(expirySecs),
    nowUtcMs: PlatformInt64Util.from(nowUtcMs),
  );

  // ── Cloud Merge ──────────────────────────────────

  Future<String> mergeCloudBackups(
    String localJson,
    String cloudJson,
    String currentDeviceId,
  ) => rust_api.mergeCloudBackups(
    localJson: localJson,
    cloudJson: cloudJson,
    currentDeviceId: currentDeviceId,
  );

  // ── S3 Parser ──────────────────────────────────

  Future<String> parseS3ListObjects(String xml) =>
      rust_api.parseS3ListObjects(xml: xml);
}
