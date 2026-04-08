import 'package:flutter/foundation.dart';

import '../../../core/data/crispy_backend.dart';
import '../../../core/utils/platform_info.dart';

/// Windows-specific AFR helper using [CrispyBackend] for FFI.
///
/// Switches display refresh rates on Windows safely via the
/// backend abstraction instead of importing `src/rust/` directly.
class WindowsAfrHelper {
  /// Creates a helper that routes FFI calls through [backend].
  WindowsAfrHelper(this._backend);

  final CrispyBackend _backend;

  /// Switches to the best matching refresh rate for the given FPS.
  Future<void> switchMode(double fps) async {
    if (!PlatformInfo.instance.isWindows) return;

    try {
      final success = await _backend.afrSwitchMode(fps);
      if (success) {
        debugPrint('AFR: Windows switched/verified for ${fps}fps content.');
      } else {
        debugPrint(
          'AFR: Windows - failed to change display mode or no match found',
        );
      }
    } catch (e) {
      debugPrint('AFR: Windows error: $e');
    }
  }

  /// Restores the original display mode.
  Future<void> restoreMode() async {
    if (!PlatformInfo.instance.isWindows) return;

    try {
      final success = await _backend.afrRestoreMode();
      if (success) {
        debugPrint('AFR: Windows restored original mode.');
      } else {
        debugPrint(
          'AFR: Windows - failed to restore display mode or no original mode',
        );
      }
    } catch (e) {
      debugPrint('AFR: Windows restore error: $e');
    }
  }
}
