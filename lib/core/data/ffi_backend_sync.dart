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

  // ── Source Sync ─────────────────────────────────

  Future<bool> verifyXtreamCredentials({
    required String baseUrl,
    required String username,
    required String password,
    bool acceptInvalidCerts = false,
  }) => rust_api.verifyXtreamCredentials(
    baseUrl: baseUrl,
    username: username,
    password: password,
    acceptInvalidCerts: acceptInvalidCerts,
  );

  Future<String> fetchXtreamAccountInfo({
    required String baseUrl,
    required String username,
    required String password,
    bool acceptInvalidCerts = false,
  }) => rust_api.fetchXtreamAccountInfo(
    baseUrl: baseUrl,
    username: username,
    password: password,
    acceptInvalidCerts: acceptInvalidCerts,
  );

  Future<String> syncXtreamSource({
    required String baseUrl,
    required String username,
    required String password,
    required String sourceId,
    bool acceptInvalidCerts = false,
    bool enrichVodOnSync = false,
  }) => rust_api.syncXtreamSource(
    baseUrl: baseUrl,
    username: username,
    password: password,
    sourceId: sourceId,
    acceptInvalidCerts: acceptInvalidCerts,
    enrichVodOnSync: enrichVodOnSync,
  );

  Future<String> syncM3uSource({
    required String url,
    required String sourceId,
    bool acceptInvalidCerts = false,
  }) async {
    return await rust_api.syncM3USource(
      url: url,
      sourceId: sourceId,
      acceptInvalidCerts: acceptInvalidCerts,
    );
  }

  Future<bool> verifyM3uUrl({
    required String url,
    bool acceptInvalidCerts = false,
  }) async {
    return await rust_api.verifyM3UUrl(
      url: url,
      acceptInvalidCerts: acceptInvalidCerts,
    );
  }

  Future<bool> verifyStalkerPortal({
    required String baseUrl,
    required String macAddress,
    bool acceptInvalidCerts = false,
  }) => rust_api.verifyStalkerPortal(
    baseUrl: baseUrl,
    macAddress: macAddress,
    acceptInvalidCerts: acceptInvalidCerts,
  );

  Future<String> syncStalkerSource({
    required String baseUrl,
    required String macAddress,
    required String sourceId,
    bool acceptInvalidCerts = false,
  }) => rust_api.syncStalkerSource(
    baseUrl: baseUrl,
    macAddress: macAddress,
    sourceId: sourceId,
    acceptInvalidCerts: acceptInvalidCerts,
  );

  Stream<String> subscribeSyncProgress() => rust_api.subscribeSyncProgress();

  // ── Stalker On-Demand ─────────────────────────────

  Future<String> resolveStalkerStreamUrl({
    required String baseUrl,
    required String macAddress,
    required String cmd,
    required String streamType,
    bool acceptInvalidCerts = false,
  }) => rust_api.resolveStalkerStreamUrl(
    baseUrl: baseUrl,
    macAddress: macAddress,
    cmd: cmd,
    streamType: streamType,
    acceptInvalidCerts: acceptInvalidCerts,
  );

  Future<String> fetchStalkerAccountInfo({
    required String baseUrl,
    required String macAddress,
    bool acceptInvalidCerts = false,
  }) => rust_api.fetchStalkerAccountInfo(
    baseUrl: baseUrl,
    macAddress: macAddress,
    acceptInvalidCerts: acceptInvalidCerts,
  );

  Future<void> stalkerKeepalive({
    required String baseUrl,
    required String macAddress,
    required String curPlayType,
    bool acceptInvalidCerts = false,
  }) => rust_api.stalkerKeepalive(
    baseUrl: baseUrl,
    macAddress: macAddress,
    curPlayType: curPlayType,
    acceptInvalidCerts: acceptInvalidCerts,
  );

  Future<String> fetchStalkerVodDetail({
    required String baseUrl,
    required String macAddress,
    required String movieId,
    required String sourceId,
    bool acceptInvalidCerts = false,
  }) => rust_api.fetchStalkerVodDetail(
    baseUrl: baseUrl,
    macAddress: macAddress,
    movieId: movieId,
    sourceId: sourceId,
    acceptInvalidCerts: acceptInvalidCerts,
  );

  Future<String> fetchStalkerSeriesDetail({
    required String baseUrl,
    required String macAddress,
    required String movieId,
    required String sourceId,
    bool acceptInvalidCerts = false,
  }) => rust_api.fetchStalkerSeriesDetail(
    baseUrl: baseUrl,
    macAddress: macAddress,
    movieId: movieId,
    sourceId: sourceId,
    acceptInvalidCerts: acceptInvalidCerts,
  );

  Future<String> getStalkerFavorites({
    required String baseUrl,
    required String macAddress,
    required String streamType,
    bool acceptInvalidCerts = false,
  }) => rust_api.getStalkerFavorites(
    baseUrl: baseUrl,
    macAddress: macAddress,
    streamType: streamType,
    acceptInvalidCerts: acceptInvalidCerts,
  );

  Future<void> setStalkerFavorite({
    required String baseUrl,
    required String macAddress,
    required String favId,
    required String streamType,
    required bool remove,
    bool acceptInvalidCerts = false,
  }) => rust_api.setStalkerFavorite(
    baseUrl: baseUrl,
    macAddress: macAddress,
    favId: favId,
    streamType: streamType,
    remove: remove,
    acceptInvalidCerts: acceptInvalidCerts,
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
