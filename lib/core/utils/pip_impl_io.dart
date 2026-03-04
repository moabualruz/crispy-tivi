import 'package:flutter/material.dart';
import 'package:floating/floating.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

/// Platform-specific PiP implementation (non-web).
class PipImpl {
  final _floating = Floating();

  /// PiP window size — 400x225 is a compact 16:9 window.
  static const _pipSize = Size(400, 225);

  /// Normal restored window size after exiting PiP.
  static const _normalSize = Size(1280, 720);

  /// Enter PiP mode.
  ///
  /// - **Android**: Uses `floating` package for system PiP.
  /// - **Desktop**: Resizes the window to a small 16:9
  ///   always-on-top window in the bottom-right corner
  ///   with the title bar hidden.
  Future<bool> enterPiP() async {
    if (Platform.isAndroid) {
      final status = await _floating.enable(const ImmediatePiP());
      return status == PiPStatus.enabled;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        // Remove title bar for a cleaner PiP look.
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSize(_pipSize);
        // Position in the bottom-right corner of the
        // screen with a small margin.
        await windowManager.setAlignment(Alignment.bottomRight);
        return true;
      } catch (e) {
        debugPrint('PiP Error (Desktop): $e');
        return false;
      }
    }
    return false;
  }

  /// Exit PiP mode.
  ///
  /// Restores the window to its normal size, removes
  /// always-on-top, restores the title bar, and centers
  /// the window.
  Future<void> exitPiP() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await windowManager.setSize(_normalSize);
        await windowManager.setAlignment(Alignment.center);
      } catch (e) {
        debugPrint('PiP Exit Error (Desktop): $e');
      }
    }
  }
}
