import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/data/cache_service.dart';

/// State of the warm failover engine.
enum WarmFailoverState {
  /// No warm player active.
  idle,

  /// A warm player is buffering the best alternative.
  warming,

  /// The warm player has buffered and is ready for instant swap.
  ready,
}

/// Near-instant stream failover via pre-buffered backup player.
///
/// Monitors buffer health and stall events, forwarding raw
/// metrics to Rust's `evaluateFailoverEvent` for threshold
/// decisions. When Rust signals `start_warming`, a hidden
/// muted [Player] pre-buffers the best alternative stream.
/// When Rust signals `swap_warm`, the warm URL is returned
/// for the primary player to switch to.
///
/// Skipped entirely on web (HTML `<video>`, not media_kit).
class WarmFailoverEngine {
  WarmFailoverEngine({required CacheService cacheService})
    : _cache = cacheService;

  final CacheService _cache;

  // ── State ──────────────────────────────────────────

  WarmFailoverState _state = WarmFailoverState.idle;
  Player? _warmPlayer;
  String? _warmUrl;
  Timer? _readyTimer;
  StreamSubscription<bool>? _playingSub;

  /// URLs already tried this failover session — prevents
  /// retry loops.
  final _triedUrls = <String>{};

  /// Current stream's URL hash (set by [setCurrentStream]).
  String? _currentUrlHash;

  /// Current channel ID (for smart group lookup).
  String? _channelId;

  /// Current channel JSON (for ranking alternatives).
  String? _channelJson;

  /// All channels JSON (for ranking alternatives).
  String? _allChannelsJson;

  /// Current state of the engine.
  WarmFailoverState get state => _state;

  /// The warm URL if state is [WarmFailoverState.ready].
  String? get warmUrl => _state == WarmFailoverState.ready ? _warmUrl : null;

  // ── Context ────────────────────────────────────────

  /// Set the current stream context for failover decisions.
  ///
  /// Called when the player opens a new live stream.
  /// [urlHash] is the hash of the stream URL.
  /// [channelJson] is the JSON of the current channel.
  /// [allChannelsJson] is the JSON array of all channels.
  void setCurrentStream({
    required String urlHash,
    required String channelJson,
    required String allChannelsJson,
    String? channelId,
  }) {
    _currentUrlHash = urlHash;
    _channelId = channelId;
    _channelJson = channelJson;
    _allChannelsJson = allChannelsJson;
  }

  // ── Event Handlers ─────────────────────────────────

  /// Forward a buffer health sample to Rust for threshold
  /// evaluation. If Rust returns `start_warming` and we're
  /// idle, begins pre-buffering the best alternative.
  Future<void> onBufferUpdate(double cacheDurationSecs) async {
    if (kIsWeb) return;
    final urlHash = _currentUrlHash;
    if (urlHash == null) return;

    final resultJson = await _cache.evaluateFailoverEvent(
      urlHash,
      'buffer',
      cacheDurationSecs,
    );
    final action = _parseAction(resultJson);

    if (action == 'start_warming') {
      await _startWarming();
    }
  }

  /// Forward a stream stall event to Rust for threshold
  /// evaluation.
  ///
  /// Returns the warm URL if Rust says `swap_warm` and the
  /// warm player is ready. Returns a cold failover URL if
  /// Rust says `swap_warm` but no warm player is ready.
  /// Returns `null` if no action needed.
  Future<String?> onStreamStall() async {
    if (kIsWeb) return null;
    final urlHash = _currentUrlHash;
    if (urlHash == null) return null;

    final resultJson = await _cache.evaluateFailoverEvent(
      urlHash,
      'stall',
      0.0,
    );
    final action = _parseAction(resultJson);

    if (action == 'swap_warm') {
      if (_state == WarmFailoverState.ready && _warmUrl != null) {
        final url = _warmUrl!;
        _triedUrls.add(url);
        await _disposeWarmPlayer();
        return url;
      }
      // No warm player ready — cold failover.
      return _coldFailoverUrl();
    }

    return null;
  }

  /// Reset all state on channel change.
  ///
  /// Disposes the warm player, clears tried URLs, and
  /// resets failover counters in Rust.
  Future<void> onChannelChange() async {
    final urlHash = _currentUrlHash;
    await _disposeWarmPlayer();
    _triedUrls.clear();
    _currentUrlHash = null;
    _channelId = null;
    _channelJson = null;
    _allChannelsJson = null;
    if (urlHash != null) {
      await _cache.resetFailoverState(urlHash);
    }
  }

  /// Whether the engine has been permanently disposed.
  bool _disposed = false;

  /// Dispose all resources.
  Future<void> dispose() async {
    _disposed = true;
    await _disposeWarmPlayer();
    _triedUrls.clear();
  }

  // ── Private ────────────────────────────────────────

  /// Start pre-buffering the best alternative stream.
  Future<void> _startWarming() async {
    // Guard: set state before async gap to prevent
    // concurrent invocations from both entering.
    if (_state != WarmFailoverState.idle || _disposed) return;
    _state = WarmFailoverState.warming;

    final bestUrl = await _findBestAlternativeUrl();
    // Re-check state after the async gap: onChannelChange() may
    // have reset state to idle while we were awaiting, or the
    // engine may have been disposed during the await. Without
    // this guard, we'd create an orphaned Player that is never
    // disposed (leaking native decoder handles).
    if (bestUrl == null || _disposed || _state != WarmFailoverState.warming) {
      if (!_disposed && _state == WarmFailoverState.warming) {
        _state = WarmFailoverState.idle;
      }
      debugPrint('WarmFailover: no alternative available or state changed');
      return;
    }

    _warmUrl = bestUrl;
    _triedUrls.add(bestUrl);

    debugPrint('WarmFailover: warming $bestUrl');

    final player = Player();
    _warmPlayer = player;

    // Muted, audio-only (no video decode) to minimize resources.
    try {
      await player.setVolume(0);
    } catch (_) {
      // Player may already be disposed if disposal raced.
    }

    // Re-check after async gap — disposal may have occurred.
    if (_disposed || _state != WarmFailoverState.warming) {
      try {
        await player.dispose();
      } catch (_) {
        // Already disposed — safe to ignore.
      }
      _warmPlayer = null;
      return;
    }

    try {
      (player.platform as dynamic).setProperty('vid', 'no');
    } catch (_) {
      // vid property may not be available on all platforms.
    }

    // Listen for playing state → transition to ready.
    _playingSub = player.stream.playing.listen((playing) {
      if (playing && _state == WarmFailoverState.warming && !_disposed) {
        _state = WarmFailoverState.ready;
        debugPrint('WarmFailover: warm player ready');
        _startReadyTimer();
      }
    });

    try {
      await player.open(Media(bestUrl));
    } catch (_) {
      // Player may have been disposed during open — safe to ignore.
    }

    // Re-check after final async gap.
    if (_disposed || _state == WarmFailoverState.idle) {
      try {
        _warmPlayer?.dispose();
      } catch (_) {
        // Already disposed — safe to ignore.
      }
      _warmPlayer = null;
    }
  }

  /// Start a 10s timer to dispose the warm player if unused.
  void _startReadyTimer() {
    _readyTimer?.cancel();
    _readyTimer = Timer(const Duration(seconds: 10), () {
      if (_state == WarmFailoverState.ready) {
        debugPrint('WarmFailover: 10s unused, disposing warm player');
        unawaited(_disposeWarmPlayer());
      }
    });
  }

  /// Find the best alternative stream URL not already tried.
  ///
  /// Smart group alternatives are checked first (user-defined
  /// priority ordering), then general stream alternatives.
  Future<String?> _findBestAlternativeUrl() async {
    // Step 1: Check smart group alternatives (prioritized).
    final channelId = _channelId;
    if (channelId != null) {
      final sgUrl = await _findSmartGroupAlternativeUrl(channelId);
      if (sgUrl != null) return sgUrl;
    }

    // Step 2: Fall back to general stream alternatives.
    final channelJson = _channelJson;
    final allChannelsJson = _allChannelsJson;
    if (channelJson == null || allChannelsJson == null) return null;

    // Get health scores for ranking.
    final healthScoresJson = '{}';

    final rankedJson = await _cache.rankStreamAlternatives(
      channelJson,
      allChannelsJson,
      healthScoresJson,
    );

    final ranked =
        (jsonDecode(rankedJson) as List).cast<Map<String, dynamic>>();

    for (final alt in ranked) {
      final url = alt['stream_url'] as String;
      if (!_triedUrls.contains(url)) {
        return url;
      }
    }

    return null;
  }

  /// Find the best untried smart group alternative URL.
  ///
  /// Returns `null` if the channel is not in a smart group
  /// or all group alternatives have been tried.
  Future<String?> _findSmartGroupAlternativeUrl(String channelId) async {
    try {
      final altsJson = await _cache.getSmartGroupAlternatives(channelId);
      final alts = (jsonDecode(altsJson) as List).cast<Map<String, dynamic>>();

      for (final alt in alts) {
        // Smart group alternatives from Rust contain channel_id
        // and source_id; resolve stream URL via allChannelsJson.
        final altChannelId = alt['channel_id'] as String;
        final url = _resolveChannelUrl(altChannelId);
        if (url != null && !_triedUrls.contains(url)) {
          return url;
        }
      }
    } catch (e) {
      debugPrint('WarmFailover: smart group lookup failed: $e');
    }
    return null;
  }

  /// Resolve a channel ID to its stream URL from the cached
  /// all-channels JSON.
  String? _resolveChannelUrl(String channelId) {
    final allJson = _allChannelsJson;
    if (allJson == null) return null;
    try {
      final channels =
          (jsonDecode(allJson) as List).cast<Map<String, dynamic>>();
      for (final ch in channels) {
        if (ch['id'] == channelId) {
          return ch['stream_url'] as String?;
        }
      }
    } catch (e) {
      debugPrint('[WarmFailoverEngine] failover attempt failed: $e');
    }
    return null;
  }

  /// Get the best untried alternative for cold failover.
  Future<String?> _coldFailoverUrl() async {
    return _findBestAlternativeUrl();
  }

  /// Dispose the warm player and reset state to idle.
  ///
  /// Awaits the mpv quiesce cycle (pause + 200ms delay)
  /// before disposing to avoid the `free_option_data`
  /// crash on rapid channel switches (media-kit#1361).
  Future<void> _disposeWarmPlayer() async {
    _readyTimer?.cancel();
    _readyTimer = null;
    _playingSub?.cancel();
    _playingSub = null;
    final player = _warmPlayer;
    _warmPlayer = null;
    _warmUrl = null;
    _state = WarmFailoverState.idle;
    if (player != null) {
      try {
        await player.pause();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } catch (_) {
        // Player may already be in a bad state — proceed to dispose.
      }
      await player.dispose();
    }
  }

  /// Parse the action field from Rust's JSON response.
  String _parseAction(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map['action'] as String? ?? 'none';
    } catch (_) {
      return 'none';
    }
  }
}
