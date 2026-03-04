import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'crispy_backend.dart';
import 'dart_algorithm_fallbacks.dart';
import 'epg_time_utils.dart';
import 'xtream_url_builder.dart';

part 'ws_backend_channels.dart';
part 'ws_backend_vod.dart';
part 'ws_backend_epg.dart';
part 'ws_backend_dvr.dart';
part 'ws_backend_profiles.dart';
part 'ws_backend_settings.dart';
part 'ws_backend_sync.dart';
part 'ws_backend_algorithms.dart';

/// Base class that exposes the WebSocket transport
/// to all mixins via the `_send` helper.
///
/// Not exported — consumers use [WsBackend].
abstract class _WsBackendBase {
  WebSocketChannel? _channel;
  int _nextId = 1;
  final _pending = <String, _PendingRequest>{};
  final _eventController = StreamController<String>.broadcast();

  /// The server URL used when reconnecting.
  String? _serverUrl;

  /// Client-side JSON ping timer (fires every 25s).
  Timer? _pingTimer;

  /// Tracks whether [dispose] has been called.
  bool _disposed = false;

  // ── Internal helpers ─────────────────────────────

  /// Send a command and await its response.
  Future<dynamic> _send(String cmd, [Map<String, dynamic>? args]) async {
    final channel = _channel;
    if (channel == null) {
      throw StateError('WsBackend not initialized');
    }
    final id = 'req-${_nextId++}';
    final completer = Completer<dynamic>();
    _pending[id] = _PendingRequest(cmd, completer);

    final msg = <String, dynamic>{'cmd': cmd, 'id': id};
    if (args != null) msg['args'] = args;
    channel.sink.add(jsonEncode(msg));

    return completer.future;
  }

  /// Handle incoming messages from the server.
  void _onMessage(dynamic raw) {
    // Ignore binary frames — only text frames carry JSON.
    if (raw is! String) return;
    if (raw.length < 500) {
      debugPrint('WsBackend _onMessage: $raw');
    } else {
      debugPrint(
        'WsBackend _onMessage: [Large Payload of length ${raw.length}]',
      );
    }
    final msg = jsonDecode(raw) as Map<String, dynamic>;

    // Ignore pong responses from the server.
    if (msg.containsKey('pong')) return;

    final id = msg['id'] as String?;
    if (id == null) {
      final event = msg['event'];
      if (event != null) {
        _eventController.add(jsonEncode(event));
      }
      return;
    }

    final req = _pending.remove(id);
    if (req == null) return;
    final cmd = req.cmd;
    final completer = req.completer;

    debugPrint(
      'WsBackend _onMessage completed command: $cmd (id: $id) with payload length: ${raw.length}',
    );

    if (msg.containsKey('error')) {
      debugPrint('WsBackend Error for $cmd ($id): ${msg['error']}');
      completer.completeError(Exception(msg['error'] as String));
    } else if (msg.containsKey('data')) {
      completer.complete(msg['data']);
    } else {
      completer.complete(msg['ok'] == true);
    }
  }

  // ── Heartbeat / keepalive ────────────────────────

  /// Start sending JSON pings every 25 seconds.
  ///
  /// The server responds with `{"pong":true}` which
  /// [_onMessage] silently discards.
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      final channel = _channel;
      if (channel != null) {
        channel.sink.add('{"ping":true}');
      }
    });
  }

  /// Cancel the ping timer.
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  // ── Channel listen / reconnect ───────────────────

  /// Attach listeners to [channel] and drive [_onMessage].
  ///
  /// Extracted so both [init] and [_reconnect] can reuse it.
  void _listenToChannel(WebSocketChannel channel) {
    channel.stream.listen(
      _onMessage,
      onError: (Object e) {
        debugPrint('WsBackend Stream Error: $e');
        for (final req in _pending.values) {
          if (!req.completer.isCompleted) {
            req.completer.completeError(e);
          }
        }
        _pending.clear();
      },
      onDone: () {
        debugPrint('WsBackend Stream Done (Closed)');
        for (final req in _pending.values) {
          if (!req.completer.isCompleted) {
            req.completer.completeError(
              const SocketException('WebSocket closed'),
            );
          }
        }
        _pending.clear();
        _reconnect();
      },
    );
  }

  /// Attempt to re-establish the connection with exponential back-off.
  ///
  /// Delays: 1s, 2s, 4s, 8s, 10s (capped), up to 10 attempts.
  /// Emits a [BulkDataRefresh] event on success so the UI reloads
  /// stale data.
  Future<void> _reconnect() async {
    if (_disposed || _serverUrl == null) return;
    _stopPingTimer();
    _channel = null;

    // Fail all pending requests immediately.
    for (final req in _pending.values) {
      if (!req.completer.isCompleted) {
        req.completer.completeError(
          const SocketException('Connection lost, reconnecting'),
        );
      }
    }
    _pending.clear();

    var delay = const Duration(seconds: 1);
    const maxDelay = Duration(seconds: 10);
    const maxAttempts = 10;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_disposed) return;
      debugPrint(
        'WsBackend: reconnect attempt $attempt/$maxAttempts '
        'in ${delay.inSeconds}s',
      );
      await Future<void>.delayed(delay);
      if (_disposed) return;

      try {
        final wsUrl = _serverUrl!.replaceFirst(RegExp(r'^http'), 'ws');
        final uri = Uri.parse('$wsUrl/ws');
        final channel = WebSocketChannel.connect(uri);
        await channel.ready;
        _channel = channel;
        _listenToChannel(channel);
        _startPingTimer();
        debugPrint('WsBackend: reconnected on attempt $attempt');

        // Signal the UI to reload all data.
        _eventController.add('{"type":"BulkDataRefresh"}');
        return;
      } catch (e) {
        debugPrint('WsBackend: reconnect attempt $attempt failed: $e');
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(
            0,
            maxDelay.inMilliseconds,
          ),
        );
      }
    }
    debugPrint('WsBackend: giving up reconnection after $maxAttempts attempts');
  }
}

class _PendingRequest {
  _PendingRequest(this.cmd, this.completer);
  final String cmd;
  final Completer<dynamic> completer;
}

/// [CrispyBackend] implementation for the web platform.
///
/// Communicates with the Rust companion server over
/// WebSocket. All data stays on the server — the browser
/// holds no local state.
class WsBackend extends _WsBackendBase
    with
        _WsChannelsMixin,
        _WsVodMixin,
        _WsEpgMixin,
        _WsDvrMixin,
        _WsProfilesMixin,
        _WsSettingsMixin,
        _WsSyncMixin,
        _WsAlgorithmsMixin
    implements CrispyBackend {
  // ── Lifecycle ────────────────────────────────────

  @override
  Future<void> init(String serverUrl) async {
    _serverUrl = serverUrl;
    _disposed = false;
    final wsUrl = serverUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final uri = Uri.parse('$wsUrl/ws');
    _channel = WebSocketChannel.connect(uri);
    await _channel!.ready;
    _listenToChannel(_channel!);
    _startPingTimer();
  }

  @override
  String version() => '0.1.0 (ws)';

  @override
  Future<String> detectGpu() async {
    final result = await _send('detectGpu');
    return result as String;
  }

  // ── Events ─────────────────────────────────────

  @override
  Stream<String> get dataEvents => _eventController.stream;
}

/// Thrown when the WebSocket connection is lost.
class SocketException implements Exception {
  /// Create with a descriptive message.
  const SocketException(this.message);

  /// Description of the error.
  final String message;

  @override
  String toString() => 'SocketException: $message';
}
