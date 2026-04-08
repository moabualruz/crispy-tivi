part of 'ws_backend.dart';

/// Buffer tier WebSocket commands.
mixin _WsBufferMixin on _WsBackendBase {
  // ── Buffer Tier ──────────────────────────────────────

  Future<String?> getBufferTier(String urlHash) async {
    final data = await _send('getBufferTier', {'urlHash': urlHash});
    return data as String?;
  }

  Future<void> setBufferTier(String urlHash, String tier) async {
    await _send('setBufferTier', {'urlHash': urlHash, 'tier': tier});
  }

  Future<int> pruneBufferTiers(int maxEntries) async {
    final data = await _send('pruneBufferTiers', {'maxEntries': maxEntries});
    return (data as num).toInt();
  }

  Future<String> evaluateBufferSample(
    String urlHash,
    double cacheDurationSecs,
  ) async {
    final data = await _send('evaluateBufferSample', {
      'urlHash': urlHash,
      'cacheDurationSecs': cacheDurationSecs,
    });
    return data as String;
  }

  Future<void> resetBufferState(String urlHash) async {
    await _send('resetBufferState', {'urlHash': urlHash});
  }

  /// Local Dart fallback — WebSocket is async and cannot
  /// serve sync calls. Mirrors Rust logic:
  /// ≤ 256 MB → 32 MB cap, ≤ 512 MB → 64 MB, else 100 MB.
  int getBufferCapMb(int heapMaxMb) {
    if (heapMaxMb <= 256) return 32;
    if (heapMaxMb <= 512) return 64;
    return 100;
  }
}
