import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/domain/entities/playlist_source.dart';

/// Interval between Stalker keepalive (watchdog) pings during playback.
const _kKeepaliveInterval = Duration(seconds: 30);

/// Manages the Stalker portal session keepalive during playback.
///
/// When a Stalker stream is playing, the portal expects periodic
/// watchdog pings to maintain the authenticated session. Without
/// these pings, the portal may terminate the stream after a timeout.
///
/// Call [startKeepalive] when Stalker playback begins and
/// [stopKeepalive] when it ends. The service handles the periodic
/// timer internally and is safe to call multiple times (idempotent).
class StalkerSessionService {
  /// Creates a [StalkerSessionService] backed by the given [Ref].
  ///
  /// The [Ref] is used to access [crispyBackendProvider] for sending
  /// keepalive pings to the Stalker portal.
  StalkerSessionService(this._ref);

  final Ref _ref;

  Timer? _keepaliveTimer;
  PlaylistSource? _activeSource;
  String? _activeStreamType;

  /// Whether a keepalive timer is currently running.
  bool get isActive => _keepaliveTimer != null;

  /// Starts periodic keepalive pings for a Stalker source.
  ///
  /// [source] must be a Stalker portal source with valid
  /// `macAddress` and `url`.
  ///
  /// [streamType] is `"itv"` for live or `"vod"` for VOD.
  ///
  /// If a keepalive is already active for a different source,
  /// the previous timer is stopped before starting the new one.
  void startKeepalive({
    required PlaylistSource source,
    required String streamType,
  }) {
    // Already running for the same source — no-op.
    if (_activeSource?.id == source.id &&
        _activeStreamType == streamType &&
        _keepaliveTimer != null) {
      return;
    }

    stopKeepalive();
    _activeSource = source;
    _activeStreamType = streamType;

    debugPrint(
      'StalkerSession: starting keepalive for '
      '${source.name} ($streamType)',
    );

    // Send first keepalive immediately, then every 30 seconds.
    _sendKeepalive();
    _keepaliveTimer = Timer.periodic(_kKeepaliveInterval, (_) {
      _sendKeepalive();
    });
  }

  /// Stops the periodic keepalive timer.
  ///
  /// Safe to call when no timer is active.
  void stopKeepalive() {
    if (_keepaliveTimer != null) {
      debugPrint('StalkerSession: stopping keepalive');
    }
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _activeSource = null;
    _activeStreamType = null;
  }

  /// Disposes resources. Must be called when the service is
  /// no longer needed.
  void dispose() {
    stopKeepalive();
  }

  void _sendKeepalive() {
    // Early bail-out: _activeSource can be nulled by
    // stopKeepalive() between timer tick and this callback.
    if (_activeSource == null) return;

    // Copy to locals before any async gap so that
    // stopKeepalive() nulling the fields mid-flight
    // cannot cause a null dereference.
    final source = _activeSource;
    final streamType = _activeStreamType;
    if (source == null || streamType == null) return;

    _ref
        .read(crispyBackendProvider)
        .stalkerKeepalive(
          baseUrl: source.url,
          macAddress: source.macAddress ?? '',
          curPlayType: streamType,
          acceptInvalidCerts: source.acceptSelfSigned,
        )
        .catchError((Object e) {
          debugPrint('StalkerSession: keepalive failed: $e');
        });
  }
}

/// Global provider for [StalkerSessionService].
///
/// Sends keepalive pings to Stalker portals during playback
/// via the Rust backend.
final stalkerSessionServiceProvider = Provider<StalkerSessionService>((ref) {
  final service = StalkerSessionService(ref);
  ref.onDispose(service.dispose);
  return service;
});
