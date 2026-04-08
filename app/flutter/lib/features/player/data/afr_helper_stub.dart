import 'package:flutter/foundation.dart';

import '../../../core/data/crispy_backend.dart';

class AfrHelper {
  AfrHelper(CrispyBackend _);

  Future<void> switchToBestMode(double fps) async {
    // No-op on web/non-supported
    debugPrint('AFR: Platform not supported for mode switching.');
  }

  Future<void> restoreMode() async {
    // No-op
  }
}
