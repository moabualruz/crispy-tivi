import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/utils/platform_capabilities.dart';

void main() {
  group('PlatformCapabilities', () {
    test('pip is false on web', () {
      // In the Flutter test environment, kIsWeb is false
      // (tests run on the Dart VM), so PiP should be true.
      // On an actual web build, PlatformCapabilities.pip
      // would be false because kIsWeb would be true.
      //
      // We verify the logic here: on non-web platforms
      // (which is the test environment), PiP should be
      // supported.
      if (kIsWeb) {
        expect(PlatformCapabilities.pip, isFalse);
      } else {
        // Test environment runs on native VM — PiP
        // should be true for desktop platforms.
        expect(PlatformCapabilities.pip, isTrue);
      }
    });

    test('externalPlayer is false on web', () {
      if (kIsWeb) {
        expect(PlatformCapabilities.externalPlayer, isFalse);
      } else {
        expect(PlatformCapabilities.externalPlayer, isTrue);
      }
    });

    test('sleepTimer is always true', () {
      expect(PlatformCapabilities.sleepTimer, isTrue);
    });

    test('fullscreen is true on desktop and web', () {
      // Test environment is native (desktop VM),
      // so fullscreen should be true.
      expect(PlatformCapabilities.fullscreen, isTrue);
    });
  });
}
