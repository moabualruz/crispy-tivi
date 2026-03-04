import 'package:flutter/foundation.dart';

/// Stub implementation for platforms without FFI support.
class WindowsAfrHelper {
  Future<void> switchMode(double fps) async {
    debugPrint('AFR: Windows helper not available on this platform.');
  }

  Future<void> restoreMode() async {
    // No-op
  }
}
