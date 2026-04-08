part of 'ffi_backend.dart';

/// Buffer tier FFI calls.
mixin _FfiBufferMixin on _FfiBackendBase {
  // ── Buffer Tier ──────────────────────────────────────

  Future<String?> getBufferTier(String urlHash) =>
      rust_api.getBufferTier(urlHash: urlHash);

  Future<void> setBufferTier(String urlHash, String tier) =>
      rust_api.setBufferTier(urlHash: urlHash, tier: tier);

  Future<int> pruneBufferTiers(int maxEntries) async {
    final result = await rust_api.pruneBufferTiers(
      maxEntries: PlatformInt64Util.from(maxEntries),
    );
    // FRB returns BigInt on native platforms.
    return result.toInt();
  }

  Future<String> evaluateBufferSample(
    String urlHash,
    double cacheDurationSecs,
  ) => rust_api.evaluateBufferSample(
    urlHash: urlHash,
    cacheDurationSecs: cacheDurationSecs,
  );

  Future<void> resetBufferState(String urlHash) =>
      rust_api.resetBufferState(urlHash: urlHash);

  int getBufferCapMb(int heapMaxMb) {
    // ignore: avoid_dynamic_calls
    final dynamic result = rust_api.getBufferCapMb(
      heapMaxMb: PlatformInt64Util.from(heapMaxMb),
    );
    // FRB returns PlatformInt64 (BigInt on web, int on native).
    return result is BigInt ? result.toInt() : (result as int);
  }
}
