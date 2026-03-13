import 'package:flutter/foundation.dart';

import '../../../core/data/crispy_backend.dart';

/// Stub implementation for platforms without FFI support.
class WindowsAfrHelper {
  WindowsAfrHelper(CrispyBackend _);

  Future<void> switchMode(double fps) async {
    debugPrint('AFR: Windows helper not available on this platform.');
  }

  Future<void> restoreMode() async {
    // No-op
  }
}
