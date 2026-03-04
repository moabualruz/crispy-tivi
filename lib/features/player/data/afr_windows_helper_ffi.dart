import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../../../src/rust/api/display.dart';

/// Windows-specific AFR helper using safe Rust FFI.
///
/// Uses flutter_rust_bridge to switch
/// display refresh rates on Windows safely.
class WindowsAfrHelper {
  /// Switches to the best matching refresh rate for the given FPS.
  Future<void> switchMode(double fps) async {
    if (!Platform.isWindows) return;

    try {
      final success = await afrSwitchMode(fps: fps);
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
    if (!Platform.isWindows) return;

    try {
      final success = await afrRestoreMode();
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
