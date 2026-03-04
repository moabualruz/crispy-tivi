import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/utils/fullscreen_helper.dart';

void main() {
  group('fullscreen_helper (stub / native)', () {
    test('toggleWebFullscreen is a no-op on native', () {
      // Should not throw.
      toggleWebFullscreen();
    });

    test('onWebFullscreenChange returns a cancel '
        'function on native', () {
      var called = false;
      final cancel = onWebFullscreenChange((isFullscreen) => called = true);

      // Callback should never be invoked on native.
      expect(called, isFalse);

      // Cancel should not throw.
      cancel();
    });

    test('isWebFullscreen returns false on native', () {
      expect(isWebFullscreen(), isFalse);
    });
  });
}
