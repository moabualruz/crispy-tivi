import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/data/cache_service.dart';

// ─────────────────────────────────────────────────────────────
//  Adaptive Buffer Manager
// ─────────────────────────────────────────────────────────────

/// Buffer quality tier — maps to mpv readahead aggressiveness.
enum BufferTier {
  /// Small buffer, fast channel switching (60 s readahead).
  fast(60),

  /// Balanced default buffer (120 s readahead).
  normal(120),

  /// Large buffer for flaky streams (180 s readahead).
  aggressive(180);

  const BufferTier(this.readaheadSecs);

  /// mpv `demuxer-readahead-secs` value for this tier.
  final int readaheadSecs;

  /// Parse from a tier name string.
  static BufferTier fromName(String name) {
    return BufferTier.values.firstWhere(
      (t) => t.name == name,
      orElse: () => BufferTier.normal,
    );
  }
}

/// Thin Dart wrapper around the Rust adaptive buffer
/// algorithm.
///
/// All tier decision logic (upgrade/downgrade thresholds,
/// counter management) runs in Rust via
/// [CacheService.evaluateBufferSample]. This class only:
///
/// 1. Hashes URLs for persistence keying.
/// 2. Forwards raw buffer samples to Rust.
/// 3. Translates Rust JSON responses into typed Dart values.
/// 4. Builds mpv property maps for each tier.
class AdaptiveBufferManager {
  AdaptiveBufferManager({required CacheService cacheService})
    : _cache = cacheService;

  final CacheService _cache;

  /// Maximum number of persisted tier entries (LRU pruned).
  static const _maxEntries = 200;

  /// Current tier for display/diagnostics.
  BufferTier _currentTier = BufferTier.normal;

  /// Current tier.
  BufferTier get currentTier => _currentTier;

  /// Hash a URL for use as the persistence key.
  ///
  /// Uses Dart's hashCode truncated to 16 hex chars for
  /// compact storage.
  static String hashUrl(String url) {
    return url.hashCode.toRadixString(16).padLeft(8, '0');
  }

  /// Initialize: prune old entries and load the tier for
  /// the first URL if known.
  Future<void> init() async {
    await _cache.pruneBufferTiers(_maxEntries);
  }

  /// Load the persisted tier for [url], defaulting to
  /// [BufferTier.normal] when none exists.
  Future<BufferTier> getTierForUrl(String url) async {
    final hash = hashUrl(url);
    final tier = await _cache.getBufferTier(hash);
    _currentTier = BufferTier.fromName(tier ?? 'normal');
    return _currentTier;
  }

  /// Feed a buffer health sample to the Rust algorithm.
  ///
  /// Returns the new [BufferTier] if it changed, or `null`
  /// if no change occurred.
  Future<BufferTier?> onBufferUpdate(
    String url,
    double cacheDurationSeconds,
  ) async {
    final hash = hashUrl(url);
    final jsonStr = await _cache.evaluateBufferSample(
      hash,
      cacheDurationSeconds,
    );

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final tierName = map['tier'] as String? ?? 'normal';
      final changed = map['changed'] as bool? ?? false;
      _currentTier = BufferTier.fromName(tierName);

      if (changed) {
        debugPrint(
          'AdaptiveBuffer: tier changed to ${_currentTier.name} '
          '(readahead=${_currentTier.readaheadSecs}s)',
        );
        return _currentTier;
      }
    } catch (e) {
      debugPrint('AdaptiveBuffer: failed to parse response: $e');
    }
    return null;
  }

  /// Build the mpv property map for a [tier].
  ///
  /// Optionally caps `demuxer-max-bytes` based on Android
  /// heap size via [bufferCapMb].
  static Map<String, dynamic> mpvOptionsForTier(
    BufferTier tier, {
    int? bufferCapMb,
  }) {
    final map = <String, dynamic>{
      'cache': 'yes',
      'cache-pause': 'no',
      'cache-pause-initial': 'no',
      'cache-pause-wait': '0',
      'demuxer-readahead-secs': tier.readaheadSecs.toString(),
    };

    if (bufferCapMb != null) {
      map['demuxer-max-bytes'] = '${bufferCapMb}M';
    }

    return map;
  }

  /// Notify the Rust side that the user changed channels.
  ///
  /// Resets in-memory health counters for the old URL and
  /// loads the persisted tier for the new one.
  Future<BufferTier> onChannelChange(String newUrl) async {
    final hash = hashUrl(newUrl);
    await _cache.resetBufferState(hash);
    return getTierForUrl(newUrl);
  }
}
