import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Proxies an MPEG-TS stream through system ffmpeg to fix codec detection.
///
/// media_kit's bundled FFmpeg cannot detect EAC-3 audio with non-standard
/// MPEG-TS codec tag 0x0087. System ffmpeg (7.x) handles this correctly.
/// This proxy pipes the stream through system ffmpeg with `-c copy` (no
/// transcoding) and serves it on a local HTTP port for mpv to play.
///
/// Desktop-only — on web, all operations return null.
class StreamProxy {
  HttpServer? _server;
  Process? _ffmpeg;
  String? _activeUrl;
  int? _port;
  final List<HttpResponse> _clients = [];

  /// Whether the proxy is currently running.
  bool get isRunning => _server != null;

  /// The local URL to play from, or null if not running.
  String? get localUrl => _port != null ? 'http://127.0.0.1:$_port/' : null;

  /// Start proxying a remote stream URL.
  ///
  /// Returns the local URL that mpv should play from, or null if
  /// ffmpeg is unavailable or on web platform.
  Future<String?> start(String remoteUrl) async {
    if (kIsWeb) return null;

    await stop();

    final ffmpegPath = await _findFfmpeg();
    if (ffmpegPath == null) {
      if (kDebugMode) {
        debugPrint('[StreamProxy] ffmpeg not found on system');
      }
      return null;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      _activeUrl = remoteUrl;

      _ffmpeg = await Process.start(ffmpegPath, [
        '-hide_banner',
        '-loglevel',
        'warning',
        '-reconnect',
        '1',
        '-reconnect_streamed',
        '1',
        '-reconnect_delay_max',
        '5',
        '-i',
        remoteUrl,
        '-c',
        'copy',
        '-f',
        'mpegts',
        'pipe:1',
      ]);

      // Log ffmpeg stderr for debugging.
      _ffmpeg!.stderr.transform(const SystemEncoding().decoder).listen((line) {
        if (kDebugMode && line.trim().isNotEmpty) {
          debugPrint('[StreamProxy] ffmpeg: ${line.trim()}');
        }
      });

      // Handle ffmpeg exit.
      _ffmpeg!.exitCode.then((code) {
        if (kDebugMode && code != 0 && _activeUrl != null) {
          debugPrint('[StreamProxy] ffmpeg exited with code $code');
        }
      });

      // Serve ffmpeg stdout to HTTP clients with data buffer.
      final dataBuffer = <List<int>>[];
      const maxBufferChunks = 64;
      final broadcast = _ffmpeg!.stdout.asBroadcastStream();

      broadcast.listen((data) {
        dataBuffer.add(data);
        if (dataBuffer.length > maxBufferChunks) {
          dataBuffer.removeAt(0);
        }
      });

      _server!.listen((request) {
        request.response.headers.contentType = ContentType('video', 'mp2t');
        request.response.headers.set('Connection', 'close');
        request.response.bufferOutput = false;
        _clients.add(request.response);

        // Send buffered data first so client gets stream headers.
        for (final chunk in dataBuffer) {
          try {
            request.response.add(chunk);
          } catch (e) {
            debugPrint('[StreamProxy] send buffered chunk failed: $e');
          }
        }

        final sub = broadcast.listen(
          (data) {
            try {
              request.response.add(data);
            } catch (e) {
              debugPrint('[StreamProxy] send stream data failed: $e');
            }
          },
          onDone: () {
            try {
              request.response.close();
            } catch (e) {
              debugPrint('[StreamProxy] close response on done failed: $e');
            }
            _clients.remove(request.response);
          },
          onError: (_) {
            try {
              request.response.close();
            } catch (e) {
              debugPrint('[StreamProxy] close response on error failed: $e');
            }
            _clients.remove(request.response);
          },
          cancelOnError: true,
        );

        request.response.done
            .then((_) {
              sub.cancel();
              _clients.remove(request.response);
            })
            .catchError((_) {
              sub.cancel();
              _clients.remove(request.response);
            });
      });

      // Wait briefly for ffmpeg to start producing data.
      await Future<void>.delayed(const Duration(seconds: 1));

      if (kDebugMode) {
        debugPrint('[StreamProxy] Started on port $_port for $remoteUrl');
      }
      return localUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StreamProxy] Failed to start: $e');
      }
      await stop();
      return null;
    }
  }

  /// Stop the proxy and clean up all resources.
  Future<void> stop() async {
    _activeUrl = null;
    _port = null;

    for (final client in _clients) {
      try {
        client.close();
      } catch (e) {
        debugPrint('[StreamProxy] close client failed: $e');
      }
    }
    _clients.clear();

    if (_ffmpeg != null) {
      try {
        _ffmpeg!.kill(ProcessSignal.sigterm);
      } catch (e) {
        debugPrint('[StreamProxy] kill ffmpeg process failed: $e');
      }
      _ffmpeg = null;
    }

    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (e) {
        debugPrint('[StreamProxy] close server failed: $e');
      }
      _server = null;
    }
  }

  /// Find ffmpeg binary on the system.
  static Future<String?> _findFfmpeg() async {
    if (Platform.isWindows) {
      // Try PATH lookup on Windows.
      try {
        final result = await Process.run('where', ['ffmpeg']);
        if (result.exitCode == 0) {
          return (result.stdout as String).trim().split('\n').first.trim();
        }
      } catch (e) {
        debugPrint('[StreamProxy] ffmpeg lookup via where failed: $e');
      }
      return null;
    }

    // Unix: check common locations.
    const paths = [
      '/opt/homebrew/bin/ffmpeg',
      '/usr/local/bin/ffmpeg',
      '/usr/bin/ffmpeg',
    ];

    for (final path in paths) {
      if (await File(path).exists()) return path;
    }

    // Try PATH lookup.
    try {
      final result = await Process.run('which', ['ffmpeg']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (e) {
      debugPrint('[StreamProxy] ffmpeg lookup via which failed: $e');
    }

    return null;
  }
}
