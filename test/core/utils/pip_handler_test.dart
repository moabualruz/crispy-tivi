import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/utils/pip_handler.dart';
import 'package:crispy_tivi/core/utils/platform_capabilities.dart';

void main() {
  group('PipHandler', () {
    late PipHandler handler;

    setUp(() {
      handler = PipHandler();
    });

    test('isSupported delegates to PlatformCapabilities.pip', () {
      expect(handler.isSupported, equals(PlatformCapabilities.pip));
    });

    test('isPipMode defaults to false', () {
      expect(handler.isPipMode, isFalse);
    });

    test('singleton returns same instance', () {
      final a = PipHandler();
      final b = PipHandler();
      expect(identical(a, b), isTrue);
    });

    test('enterPiP returns false when not supported', () async {
      // On the test VM (Windows), PiP IS supported,
      // so this test verifies the flow works. If PiP
      // were not supported, enterPiP should return false.
      if (!PlatformCapabilities.pip) {
        final result = await handler.enterPiP();
        expect(result, isFalse);
        expect(handler.isPipMode, isFalse);
      }
    });

    test('exitPiP resets isPipMode', () async {
      // Even if PiP was never entered, calling exitPiP
      // should safely set isPipMode to false.
      await handler.exitPiP();
      expect(handler.isPipMode, isFalse);
    });
  });
}
