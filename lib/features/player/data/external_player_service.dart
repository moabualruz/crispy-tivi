import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

/// Known external player apps and their identifiers.
enum ExternalPlayer {
  /// System default — uses url_launcher to open stream URL.
  systemDefault('System Default', null),

  /// VLC Media Player.
  vlc('VLC', 'org.videolan.vlc'),

  /// MX Player.
  mxPlayer('MX Player', 'com.mxtech.videoplayer.ad'),

  /// MX Player Pro.
  mxPlayerPro('MX Player Pro', 'com.mxtech.videoplayer.pro'),

  /// Kodi.
  kodi('Kodi', 'org.xbmc.kodi'),

  /// Just Player.
  justPlayer('Just Player', 'com.brouken.player'),

  /// mpv (Android / Desktop).
  mpv('mpv', 'is.xyz.mpv');

  const ExternalPlayer(this.label, this.androidPackage);

  /// Display name for the UI.
  final String label;

  /// Android package name (null for system default).
  final String? androidPackage;
}

/// Service for launching streams in external player apps.
///
/// Supports:
/// - **Android/iOS**: `vlc://` protocol scheme for VLC,
///   intent-based launch for MX Player/Kodi/mpv.
/// - **Desktop** (Windows/Linux/macOS): Binary launch with
///   `--play-and-exit` for VLC, `--untitled-window` for mpv.
///   Falls back to `vlc://` URL scheme, then system launcher.
/// - **Web**: Not supported (button hidden via
///   [PlatformCapabilities.externalPlayer]).
class ExternalPlayerService {
  /// Launch a stream URL in an external player.
  ///
  /// [streamUrl] is the media URL to play.
  /// [player] is the chosen external player app.
  /// [title] is the stream title (passed as intent extra
  /// where supported).
  /// [headers] are custom HTTP headers (User-Agent, auth,
  /// etc.) passed to the external player where supported.
  ///
  /// Returns `true` if the launch was successful.
  Future<bool> launch({
    required String streamUrl,
    ExternalPlayer player = ExternalPlayer.systemDefault,
    String? title,
    Map<String, String>? headers,
  }) async {
    // Web: use protocol URL schemes.
    if (kIsWeb) {
      return _launchWeb(streamUrl, player: player);
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return _launchMobile(
        streamUrl,
        player: player,
        title: title,
        headers: headers,
      );
    }

    // Desktop (Windows / Linux / macOS).
    return _launchDesktop(
      streamUrl,
      player: player,
      title: title,
      headers: headers,
    );
  }

  // ──────────────────────────────────────────────────────
  //  Mobile (Android + iOS)
  // ──────────────────────────────────────────────────────

  /// Launch on Android / iOS via URL schemes.
  Future<bool> _launchMobile(
    String streamUrl, {
    ExternalPlayer player = ExternalPlayer.systemDefault,
    String? title,
    Map<String, String>? headers,
  }) async {
    switch (player) {
      case ExternalPlayer.vlc:
        return _launchVlcMobile(streamUrl);

      case ExternalPlayer.mxPlayer:
      case ExternalPlayer.mxPlayerPro:
        return _launchMxPlayer(
          streamUrl,
          player: player,
          title: title,
          headers: headers,
        );

      case ExternalPlayer.kodi:
        return _launchKodi(streamUrl);

      case ExternalPlayer.justPlayer:
      case ExternalPlayer.mpv:
        return _launchWithPackage(streamUrl, player: player);

      case ExternalPlayer.systemDefault:
        return _launchSystemDefault(streamUrl);
    }
  }

  /// VLC on Android/iOS: `vlc://{url}` protocol scheme.
  ///
  /// The `vlc://` scheme is registered by VLC on both
  /// Android and iOS. The URL is placed directly after
  /// the scheme prefix.
  Future<bool> _launchVlcMobile(String streamUrl) async {
    final vlcUri = Uri.parse('vlc://$streamUrl');
    try {
      if (await canLaunchUrl(vlcUri)) {
        return launchUrl(vlcUri);
      }
    } catch (e) {
      debugPrint('VLC vlc:// scheme failed: $e');
    }

    // Fallback: try intent-style launch for Android.
    if (Platform.isAndroid) {
      return _launchWithIntentUri(
        streamUrl,
        package: ExternalPlayer.vlc.androidPackage!,
      );
    }

    // iOS fallback: try system default.
    return _launchSystemDefault(streamUrl);
  }

  /// MX Player on Android: launch with intent extras.
  ///
  /// MX Player supports receiving title via intent extras
  /// and custom headers via a `headers` extra array.
  Future<bool> _launchMxPlayer(
    String streamUrl, {
    required ExternalPlayer player,
    String? title,
    Map<String, String>? headers,
  }) async {
    // Build the intent URI with extras for MX Player.
    // MX Player accepts:
    //   - title: display title
    //   - headers: String[] of "Key: Value" pairs
    final sb =
        StringBuffer()
          ..write('intent:')
          ..write(Uri.encodeFull(streamUrl))
          ..write('#Intent;')
          ..write('type=video/*;')
          ..write('package=${player.androidPackage};');

    if (title != null) {
      sb.write('S.title=${Uri.encodeComponent(title)};');
    }

    if (headers != null && headers.isNotEmpty) {
      // MX Player accepts headers as an array of
      // "Key: Value" strings.
      for (final entry in headers.entries) {
        sb.write(
          'S.headers=${Uri.encodeComponent('${entry.key}: ${entry.value}')};',
        );
      }
    }

    sb.write('end');

    final intentUri = Uri.parse(sb.toString());
    try {
      if (await canLaunchUrl(intentUri)) {
        return launchUrl(intentUri);
      }
    } catch (e) {
      debugPrint('MX Player intent launch failed: $e');
    }

    // Fallback: plain URL with externalApplication mode.
    return _launchSystemDefault(streamUrl);
  }

  /// Kodi: launch via its intent scheme.
  Future<bool> _launchKodi(String streamUrl) async {
    // Kodi does not support a simple URL scheme for
    // playback on Android. Use intent-based launch.
    if (Platform.isAndroid) {
      return _launchWithIntentUri(
        streamUrl,
        package: ExternalPlayer.kodi.androidPackage!,
      );
    }
    return _launchSystemDefault(streamUrl);
  }

  /// Launch with Android intent URI for a specific package.
  Future<bool> _launchWithIntentUri(
    String streamUrl, {
    required String package,
  }) async {
    final intentUri = Uri.parse(
      'intent:${Uri.encodeFull(streamUrl)}'
      '#Intent;type=video/*;package=$package;end',
    );
    try {
      if (await canLaunchUrl(intentUri)) {
        return launchUrl(intentUri);
      }
    } catch (e) {
      debugPrint('Intent launch for $package failed: $e');
    }
    return _launchSystemDefault(streamUrl);
  }

  /// Launch with a specific Android package via intent.
  Future<bool> _launchWithPackage(
    String streamUrl, {
    required ExternalPlayer player,
  }) async {
    if (Platform.isAndroid && player.androidPackage != null) {
      return _launchWithIntentUri(streamUrl, package: player.androidPackage!);
    }
    // iOS: most players don't have URL schemes, fall back.
    return _launchSystemDefault(streamUrl);
  }

  // ──────────────────────────────────────────────────────
  //  Desktop (Windows / Linux / macOS)
  // ──────────────────────────────────────────────────────

  /// Launch on desktop via binary execution.
  ///
  /// Tries to locate the player binary and launch it
  /// directly with appropriate flags. Falls back to URL
  /// scheme and then system launcher.
  Future<bool> _launchDesktop(
    String streamUrl, {
    ExternalPlayer player = ExternalPlayer.systemDefault,
    String? title,
    Map<String, String>? headers,
  }) async {
    switch (player) {
      case ExternalPlayer.vlc:
        return _launchVlcDesktop(streamUrl, title: title, headers: headers);

      case ExternalPlayer.mpv:
        return _launchMpvDesktop(streamUrl, title: title, headers: headers);

      case ExternalPlayer.kodi:
      case ExternalPlayer.mxPlayer:
      case ExternalPlayer.mxPlayerPro:
      case ExternalPlayer.justPlayer:
        // These players are mobile-only. Fall back to
        // system default on desktop.
        return _launchSystemDefault(streamUrl);

      case ExternalPlayer.systemDefault:
        return _launchSystemDefault(streamUrl);
    }
  }

  /// VLC on desktop: launch binary with `--play-and-exit`.
  ///
  /// Detects VLC binary path from common installation
  /// locations or PATH. Passes `--play-and-exit` so VLC
  /// closes when playback finishes. Supports header
  /// passthrough via `--http-user-agent` and
  /// `--http-referrer`.
  Future<bool> _launchVlcDesktop(
    String streamUrl, {
    String? title,
    Map<String, String>? headers,
  }) async {
    final vlcPath = await _findVlcBinary();

    if (vlcPath != null) {
      final args = <String>[
        '--play-and-exit',
        if (title != null) ...['--meta-title', title],
        // Pass headers where VLC supports them.
        if (headers != null) ...[
          if (headers.containsKey('User-Agent'))
            '--http-user-agent=${headers['User-Agent']}',
          if (headers.containsKey('Referer'))
            '--http-referrer=${headers['Referer']}',
        ],
        streamUrl,
      ];

      try {
        final result = await Process.start(
          vlcPath,
          args,
          mode: ProcessStartMode.detached,
        );
        // Detached process — VLC runs independently.
        // Non-zero PID means it started.
        return result.pid > 0;
      } catch (e) {
        debugPrint('VLC binary launch failed: $e');
      }
    }

    // Fallback: try vlc:// URL scheme.
    final vlcUri = Uri.parse('vlc://$streamUrl');
    try {
      if (await canLaunchUrl(vlcUri)) {
        return launchUrl(vlcUri);
      }
    } catch (e) {
      debugPrint('VLC vlc:// scheme failed: $e');
    }

    // Final fallback: system default.
    return _launchSystemDefault(streamUrl);
  }

  /// mpv on desktop: launch binary with stream URL.
  ///
  /// Detects mpv binary from PATH. Passes
  /// `--force-window=yes` and `--title` for proper
  /// windowed playback. Supports header passthrough via
  /// `--http-header-fields`.
  Future<bool> _launchMpvDesktop(
    String streamUrl, {
    String? title,
    Map<String, String>? headers,
  }) async {
    final mpvPath = await _findBinaryInPath('mpv');

    if (mpvPath != null) {
      final args = <String>[
        '--force-window=yes',
        if (title != null) '--title=$title',
        if (headers != null && headers.isNotEmpty)
          '--http-header-fields=${headers.entries.map((e) => '${e.key}: ${e.value}').join(',')}',
        streamUrl,
      ];

      try {
        final result = await Process.start(
          mpvPath,
          args,
          mode: ProcessStartMode.detached,
        );
        return result.pid > 0;
      } catch (e) {
        debugPrint('mpv binary launch failed: $e');
      }
    }

    // Fallback: system default.
    return _launchSystemDefault(streamUrl);
  }

  // ──────────────────────────────────────────────────────
  //  Binary detection helpers
  // ──────────────────────────────────────────────────────

  /// Well-known VLC installation paths by platform.
  static const _vlcPaths = {
    'windows': [
      r'C:\Program Files\VideoLAN\VLC\vlc.exe',
      r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe',
    ],
    'macos': ['/Applications/VLC.app/Contents/MacOS/VLC'],
    'linux': ['/usr/bin/vlc', '/snap/bin/vlc', '/usr/local/bin/vlc'],
  };

  /// Find the VLC binary on the current platform.
  ///
  /// Checks well-known installation paths first, then
  /// falls back to searching PATH.
  Future<String?> _findVlcBinary() async {
    if (kIsWeb) return null;

    // Check well-known paths.
    final String platformKey;
    if (Platform.isWindows) {
      platformKey = 'windows';
    } else if (Platform.isMacOS) {
      platformKey = 'macos';
    } else {
      platformKey = 'linux';
    }

    final knownPaths = _vlcPaths[platformKey] ?? [];
    for (final path in knownPaths) {
      if (await File(path).exists()) {
        return path;
      }
    }

    // Search PATH.
    final binaryName = Platform.isWindows ? 'vlc.exe' : 'vlc';
    return _findBinaryInPath(binaryName);
  }

  /// Search for a binary name in the system PATH.
  Future<String?> _findBinaryInPath(String binaryName) async {
    if (kIsWeb) return null;

    try {
      // Use `where` on Windows, `which` on Unix.
      final cmd = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(cmd, [binaryName]);
      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        // `where` on Windows may return multiple lines.
        final firstLine = output.split('\n').first.trim();
        if (firstLine.isNotEmpty) {
          return firstLine;
        }
      }
    } catch (e) {
      debugPrint('Binary search for $binaryName failed: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────
  //  System default launcher
  // ──────────────────────────────────────────────────────

  /// Open stream URL with the system default handler.
  Future<bool> _launchSystemDefault(String streamUrl) async {
    final uri = Uri.parse(streamUrl);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('System default launch failed: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────
  //  Web (protocol URL schemes)
  // ──────────────────────────────────────────────────────

  /// Launch on web using protocol URL schemes.
  ///
  /// Builds a protocol URL for the chosen player and
  /// opens it via url_launcher. The browser hands off
  /// to a locally installed player.
  Future<bool> _launchWeb(
    String streamUrl, {
    ExternalPlayer player = ExternalPlayer.systemDefault,
  }) async {
    final protocolUrl = protocolUrlFor(streamUrl, player);
    final uri = Uri.parse(protocolUrl ?? streamUrl);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Web protocol launch failed: $e');
      return false;
    }
  }

  /// Build a protocol URL string for the given player.
  ///
  /// Returns null if no known protocol URL exists.
  static String? protocolUrlFor(String streamUrl, ExternalPlayer player) {
    switch (player) {
      case ExternalPlayer.vlc:
        return 'vlc://$streamUrl';
      case ExternalPlayer.mpv:
      case ExternalPlayer.kodi:
      case ExternalPlayer.mxPlayer:
      case ExternalPlayer.mxPlayerPro:
      case ExternalPlayer.justPlayer:
      case ExternalPlayer.systemDefault:
        return null;
    }
  }
}

/// Global provider for external player service.
final externalPlayerServiceProvider = Provider<ExternalPlayerService>(
  (_) => ExternalPlayerService(),
);
