import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/data/pip_handoff_policy.dart';

void main() {
  group('PipHandoffPolicy', () {
    test('isAvailable returns false on non-iOS platforms', () {
      // Tests run on the host (Windows/Linux/macOS), not iOS.
      final policy = PipHandoffPolicy();
      expect(policy.isAvailable, isFalse);
    });
  });
}
