import 'package:flutter/material.dart';
import 'package:floating/floating.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

/// Platform-specific PiP implementation (non-web).
class PipImpl {
  final _floating = Floating();

  /// PiP window size — 400x225 is a compact 16:9 window.
  static const _pipSize = Size(400, 225);

  /// Pre-PiP window bounds, saved on enter and restored
  /// on exit (WIN-04).
  Size? _prePipSize;
  Offset? _prePipPosition;

  /// Enter PiP mode.
  ///
  /// - **Android**: Uses `floating` package for system PiP.
  /// - **Desktop**: Saves window bounds, hides from taskbar,
  ///   resizes to a small 16:9 always-on-top window in the
  ///   bottom-right corner with the title bar hidden.
  Future<bool> enterPiP() async {
    if (Platform.isAndroid) {
      final status = await _floating.enable(const ImmediatePiP());
      return status == PiPStatus.enabled;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        // WIN-04: Save current bounds for restoration.
        _prePipSize = await windowManager.getSize();
        _prePipPosition = await windowManager.getPosition();
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await windowManager.setSkipTaskbar(true);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSize(_pipSize);
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
  /// Restores the window to its pre-PiP size and position,
  /// removes always-on-top, shows in taskbar, and restores
  /// the title bar.
  Future<void> exitPiP() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setSkipTaskbar(false);
        // WIN-03: Restore title bar (was incorrectly hidden).
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
        // WIN-04: Restore pre-PiP bounds instead of hardcoded size.
        if (_prePipSize != null) {
          await windowManager.setSize(_prePipSize!);
        }
        if (_prePipPosition != null) {
          await windowManager.setPosition(_prePipPosition!);
        } else {
          await windowManager.setAlignment(Alignment.center);
        }
        _prePipSize = null;
        _prePipPosition = null;
      } catch (e) {
        debugPrint('PiP Exit Error (Desktop): $e');
      }
    }
  }
}
