import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:universal_io/io.dart';

/// Thin wrapper around the `screen_brightness` package.
///
/// Safe to call on any platform — non-mobile platforms
/// silently no-op since the plugin only supports Android/iOS.
abstract final class ScreenBrightnessHelper {
  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Set screen brightness to [value] (0.0–1.0).
  static Future<void> setBrightness(double value) async {
    if (!_isMobile) return;
    try {
      await ScreenBrightness().setScreenBrightness(value);
    } catch (_) {
      // Plugin unavailable or permission denied — ignore.
    }
  }

  /// Reset screen brightness to system default.
  static Future<void> resetBrightness() async {
    if (!_isMobile) return;
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (_) {
      // Plugin unavailable — ignore.
    }
  }

  /// Get current screen brightness (0.0–1.0), or 1.0 on error.
  static Future<double> getCurrentBrightness() async {
    if (!_isMobile) return 1.0;
    try {
      return await ScreenBrightness().current;
    } catch (_) {
      return 1.0;
    }
  }
}
