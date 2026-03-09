import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

import 'window_config.dart';

/// Platform-specific PiP implementation (non-web).
///
/// - **Android**: Uses `crispy/pip` MethodChannel for native
///   `PictureInPictureParams`.
/// - **iOS**: Uses `crispy/pip` MethodChannel (delegates to
///   `CrispyPipPlayerPlugin`).
/// - **Desktop**: Uses `window_manager` to resize window,
///   set always-on-top, and position bottom-right.
class PipImpl {
  static const _channel = MethodChannel('crispy/pip');

  /// PiP window size — 400x225 is a compact 16:9 window.
  static const _pipSize = Size(400, 225);

  /// Pre-PiP window bounds, saved on enter and restored
  /// on exit.
  Size? _prePipSize;
  Offset? _prePipPosition;

  /// Whether PiP is supported on this platform.
  bool get isSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isWindows ||
      Platform.isMacOS ||
      Platform.isLinux;

  /// Callback invoked when native PiP state changes
  /// (e.g. user dismisses the PiP window on Android).
  void Function(bool isInPip)? onNativePipChanged;

  PipImpl() {
    // Listen for native PiP state changes from Android.
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onNativePipChanged') {
      final args = call.arguments as Map?;
      final isInPip = args?['isInPip'] as bool? ?? false;
      onNativePipChanged?.call(isInPip);
    }
  }

  /// Enter PiP mode.
  ///
  /// Returns `(true, null)` on success, or
  /// `(false, errorMessage)` on failure.
  Future<(bool, String?)> enterPiP({int? width, int? height}) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return _enterMobilePiP(width: width, height: height);
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _enterDesktopPiP();
    }
    return (false, null);
  }

  /// Exit PiP mode.
  Future<void> exitPiP() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _channel.invokeMethod<void>('exitPip');
      } on PlatformException {
        // Ignored — state is cleared by caller.
      }
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _exitDesktopPiP();
    }
  }

  /// Arm/disarm native auto-PiP for background entry.
  ///
  /// - **Android API 31+**: Sets `setAutoEnterEnabled(true)`
  ///   so the OS auto-enters PiP on home press.
  /// - **Android API 26-30**: Saves flag for
  ///   `onUserLeaveHint()` fallback.
  /// - **iOS**: No native auto-PiP; Dart lifecycle handler
  ///   calls [enterPiP] directly on background.
  Future<void> setAutoPipReady({
    required bool ready,
    int? width,
    int? height,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setAutoPipReady', {
        'ready': ready,
        'width': width ?? 16,
        'height': height ?? 9,
      });
    } on PlatformException {
      // Ignored — auto-PiP is a best-effort feature.
    }
  }

  /// Save current PiP window bounds for cross-session persistence.
  Future<void> savePipBounds() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    try {
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('pip_width', size.width);
      await prefs.setDouble('pip_height', size.height);
      await prefs.setDouble('pip_x', pos.dx);
      await prefs.setDouble('pip_y', pos.dy);
    } catch (_) {}
  }

  /// Load saved PiP window bounds, if any.
  Future<(Size?, Offset?)> _loadPipBounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final w = prefs.getDouble('pip_width');
      final h = prefs.getDouble('pip_height');
      final x = prefs.getDouble('pip_x');
      final y = prefs.getDouble('pip_y');
      final size = (w != null && h != null) ? Size(w, h) : null;
      final pos = (x != null && y != null) ? Offset(x, y) : null;
      return (size, pos);
    } catch (_) {
      return (null, null);
    }
  }

  // ── Mobile (Android / iOS) ─────────────────────────

  Future<(bool, String?)> _enterMobilePiP({int? width, int? height}) async {
    try {
      final result = await _channel.invokeMethod<Map>('enterPip', {
        'width': width,
        'height': height,
      });
      if (result != null) {
        final success = result['success'] as bool? ?? true;
        final errorCode = result['errorCode'] as String?;
        return (success, errorCode);
      }
      // Null result = success (legacy Android handler).
      return (true, null);
    } on PlatformException catch (e) {
      return (false, e.message ?? e.code);
    }
  }

  // ── Desktop (Windows / macOS / Linux) ──────────────

  Future<(bool, String?)> _enterDesktopPiP() async {
    try {
      _prePipSize = await windowManager.getSize();
      _prePipPosition = await windowManager.getPosition();
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setMinimumSize(const Size(200, 112));
      await windowManager.setMaximumSize(const Size(800, 450));

      // Restore saved PiP bounds, or default to 400x225 bottom-right.
      final (savedSize, savedPos) = await _loadPipBounds();
      await windowManager.setSize(savedSize ?? _pipSize);
      if (savedPos != null) {
        await windowManager.setPosition(savedPos);
      } else {
        await windowManager.setAlignment(Alignment.bottomRight);
      }
      return (true, null);
    } catch (e) {
      debugPrint('PiP Error (Desktop): $e');
      return (false, e.toString());
    }
  }

  Future<void> _exitDesktopPiP() async {
    try {
      // Persist PiP position/size before restoring.
      await savePipBounds();
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.setTitleBarStyle(
        kUseCustomTitleBar ? TitleBarStyle.hidden : TitleBarStyle.normal,
      );
      // Remove PiP size constraints.
      await windowManager.setMinimumSize(const Size(800, 600));
      await windowManager.setMaximumSize(Size.infinite);
      // Restore pre-PiP bounds.
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
