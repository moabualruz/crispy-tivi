import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart';

import 'device_form_factor.dart';

/// Central registry of platform-specific feature
/// availability.
///
/// Use `PlatformCapabilities.xyz` to check if a feature
/// is supported before showing its UI control.
abstract final class PlatformCapabilities {
  /// Picture-in-Picture.
  /// Supported on all 6 platforms: Android (native),
  /// iOS (AVPiP via IosPipPlayer), desktop
  /// (window_manager), web (browser PiP API).
  static bool get pip => true;

  /// External player (open in VLC, MX Player, etc.).
  /// Available on all platforms. On web, uses protocol
  /// URL schemes (e.g. vlc://).
  static bool get externalPlayer => true;

  /// Chromecast / Google Cast discovery.
  /// Requires mDNS on the local network — not
  /// available on web.
  static bool get cast => !kIsWeb;

  /// AirPlay.
  /// Only supported on iOS and macOS.
  static bool get airplay => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// Sleep timer.
  /// Available on all platforms.
  static bool get sleepTimer => true;

  /// Window manager features (fullscreen toggle).
  /// Desktop and web only.
  static bool get fullscreen =>
      kIsWeb ||
      (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux));

  /// Haptic feedback.
  /// Mobile only.
  static bool get haptic => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// True when running on an Android TV device (leanback mode).
  static bool get isTV => DeviceFormFactorService.current.isTV;
}
