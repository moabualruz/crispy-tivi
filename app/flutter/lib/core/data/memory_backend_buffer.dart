part of 'memory_backend.dart';

/// Buffer tier in-memory implementation for [MemoryBackend].
mixin _MemoryBufferMixin on _MemoryStorage {
  // ── Buffer Tier ──────────────────────────────────────

  Future<String?> getBufferTier(String urlHash) async => bufferTiers[urlHash];

  Future<void> setBufferTier(String urlHash, String tier) async {
    bufferTiers[urlHash] = tier;
  }

  Future<int> pruneBufferTiers(int maxEntries) async {
    final excess = bufferTiers.length - maxEntries;
    if (excess <= 0) return 0;
    final toRemove = bufferTiers.keys.take(excess).toList();
    for (final key in toRemove) {
      bufferTiers.remove(key);
    }
    return toRemove.length;
  }

  /// Returns the stored tier unchanged (no sample
  /// evaluation in the in-memory backend).
  ///
  /// Always returns
  /// `{"tier":"normal","changed":false,"readahead_secs":120}`
  /// unless a tier has been explicitly set, in which
  /// case it returns that tier with `"changed":false`.
  Future<String> evaluateBufferSample(
    String urlHash,
    double cacheDurationSecs,
  ) async {
    final tier = bufferTiers[urlHash] ?? 'normal';
    return '{"tier":"$tier","changed":false,"readahead_secs":120}';
  }

  Future<void> resetBufferState(String urlHash) async {
    // No in-memory counters to reset.
  }

  /// Mirrors Rust logic:
  /// ≤ 256 MB → 32 MB cap, ≤ 512 MB → 64 MB, else 100 MB.
  int getBufferCapMb(int heapMaxMb) {
    if (heapMaxMb <= 256) return 32;
    if (heapMaxMb <= 512) return 64;
    return 100;
  }
}
