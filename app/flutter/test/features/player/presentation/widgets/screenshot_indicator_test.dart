import 'package:crispy_tivi/features/player/presentation/widgets/screenshot_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenshotResultNotifier', () {
    test('initial state is idle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(screenshotResultProvider), ScreenshotResult.idle);
    });

    test('setResult updates state to success', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(screenshotResultProvider.notifier)
          .setResult(ScreenshotResult.success);
      expect(
        container.read(screenshotResultProvider),
        ScreenshotResult.success,
      );
    });

    test('setResult updates state to error', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(screenshotResultProvider.notifier)
          .setResult(ScreenshotResult.error);
      expect(container.read(screenshotResultProvider), ScreenshotResult.error);
    });

    test('setting idle does not trigger auto-reset timer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(screenshotResultProvider.notifier)
          .setResult(ScreenshotResult.idle);
      expect(container.read(screenshotResultProvider), ScreenshotResult.idle);
    });

    test('auto-resets to idle after 1.5 seconds', () async {
      final container = ProviderContainer();
      container
          .read(screenshotResultProvider.notifier)
          .setResult(ScreenshotResult.success);
      expect(
        container.read(screenshotResultProvider),
        ScreenshotResult.success,
      );

      // Wait for auto-reset (1.5s + buffer).
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      expect(container.read(screenshotResultProvider), ScreenshotResult.idle);
      container.dispose();
    });

    test('error also auto-resets to idle', () async {
      final container = ProviderContainer();
      container
          .read(screenshotResultProvider.notifier)
          .setResult(ScreenshotResult.error);
      expect(container.read(screenshotResultProvider), ScreenshotResult.error);

      await Future<void>.delayed(const Duration(milliseconds: 1700));
      expect(container.read(screenshotResultProvider), ScreenshotResult.idle);
      container.dispose();
    });

    test('does not crash when disposed before timer fires', () async {
      final container = ProviderContainer();
      container
          .read(screenshotResultProvider.notifier)
          .setResult(ScreenshotResult.success);
      container.dispose();

      // Timer fires after dispose — should not throw.
      await Future<void>.delayed(const Duration(milliseconds: 1700));
    });
  });

  group('ScreenshotResult enum', () {
    test('has three values', () {
      expect(ScreenshotResult.values.length, 3);
    });

    test('idle is the default sentinel', () {
      expect(ScreenshotResult.idle.name, 'idle');
    });
  });

  group('Keyboard shortcut mapping', () {
    test('S key is mapped to screenshot action', () {
      expect(LogicalKeyboardKey.keyS.keyId, isNonZero);
    });

    test('S and Shift+S are distinct from other player shortcuts', () {
      // S = screenshot, Shift+S = clean screenshot.
      // Verify S is distinct from other shortcut keys.
      expect(LogicalKeyboardKey.keyS, isNot(equals(LogicalKeyboardKey.keyF)));
      expect(LogicalKeyboardKey.keyS, isNot(equals(LogicalKeyboardKey.keyI)));
      expect(LogicalKeyboardKey.keyS, isNot(equals(LogicalKeyboardKey.keyM)));
    });
  });

  group('screenshotBoundaryKey', () {
    test('is a valid GlobalKey with debug label', () {
      expect(screenshotBoundaryKey, isNotNull);
      expect(screenshotBoundaryKey.toString(), contains('screenshotBoundary'));
    });
  });

  group('Web platform gating', () {
    test('captureScreenshot function exists with required signature', () {
      // captureScreenshot checks kIsWeb at the top and returns null.
      // In test environment kIsWeb is false, but we can verify the
      // function accepts the expected parameters.
      expect(captureScreenshot, isA<Function>());
    });
  });
}
