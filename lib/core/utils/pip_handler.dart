import '../utils/platform_capabilities.dart';
import 'pip_impl.dart';

/// Unified handler for Picture-in-Picture (PiP) mode.
///
/// - **Android**: Uses `floating` package for native PiP.
/// - **Desktop**: Uses `window_manager` to resize window,
///   set always-on-top, and position bottom-right.
/// - **Web**: Not supported — button is hidden.
class PipHandler {
  static final PipHandler _instance = PipHandler._internal();
  factory PipHandler() => _instance;
  PipHandler._internal();

  final _impl = PipImpl();
  bool _isPipMode = false;

  /// Whether the app is currently in PiP mode.
  bool get isPipMode => _isPipMode;

  /// Whether PiP is supported on the current platform.
  ///
  /// Delegates to [PlatformCapabilities.pip] — the
  /// single source of truth. Returns `true` on Android
  /// and desktop; `false` on web and iOS.
  bool get isSupported => PlatformCapabilities.pip;

  /// Request to enter PiP mode.
  Future<bool> enterPiP() async {
    if (!isSupported) return false;

    final success = await _impl.enterPiP();
    if (success) {
      _isPipMode = true;
    }
    return success;
  }

  /// Request to exit PiP mode.
  Future<void> exitPiP() async {
    if (!isSupported) return;

    await _impl.exitPiP();
    _isPipMode = false;
  }

  /// Toggle PiP mode.
  Future<void> togglePiP() async {
    if (_isPipMode) {
      await exitPiP();
    } else {
      await enterPiP();
    }
  }
}
