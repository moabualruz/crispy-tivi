part of 'ffi_backend.dart';

/// Stream health and alternatives FFI calls.
mixin _FfiStreamHealthMixin on _FfiBackendBase {
  // ── Stream Health ──────────────────────────────────

  Future<void> recordStreamStall(String urlHash) =>
      rust_api.recordStreamStall(urlHash: urlHash);

  Future<void> recordStreamBufferSample(
    String urlHash,
    double cacheDurationSecs,
  ) => rust_api.recordBufferSample(
    urlHash: urlHash,
    cacheDurationSecs: cacheDurationSecs,
  );

  Future<void> recordStreamTtff(String urlHash, int ttffMs) => rust_api
      .recordTtff(urlHash: urlHash, ttffMs: PlatformInt64Util.from(ttffMs));

  Future<double> getStreamHealthScore(String urlHash) =>
      rust_api.getStreamHealthScore(urlHash: urlHash);

  Future<String> getStreamHealthScores(String urlHashesJson) =>
      rust_api.getStreamHealthScores(urlHashesJson: urlHashesJson);

  Future<int> pruneStreamHealth(int maxEntries) async {
    final result = await rust_api.pruneStreamHealth(
      maxEntries: PlatformInt64Util.from(maxEntries),
    );
    return result.toInt();
  }

  Future<String> evaluateFailoverEvent(
    String urlHash,
    String eventType,
    double value,
  ) => rust_api.evaluateFailoverEvent(
    urlHash: urlHash,
    eventType: eventType,
    value: value,
  );

  Future<void> resetFailoverState(String urlHash) =>
      rust_api.resetFailoverState(urlHash: urlHash);

  // ── Stream Alternatives ────────────────────────────

  Future<String> rankStreamAlternatives(
    String targetJson,
    String allChannelsJson,
    String healthScoresJson,
  ) => rust_api.rankStreamAlternatives(
    targetJson: targetJson,
    allChannelsJson: allChannelsJson,
    healthScoresJson: healthScoresJson,
  );

  String extractCallSign(String name) => rust_api.extractCallSign(name: name);
}
