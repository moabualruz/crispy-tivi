import 'package:flutter/foundation.dart';

class AfrHelper {
  Future<void> switchToBestMode(double fps) async {
    // No-op on web/non-supported
    debugPrint('AFR: Platform not supported for mode switching.');
  }

  Future<void> restoreMode() async {
    // No-op
  }
}
