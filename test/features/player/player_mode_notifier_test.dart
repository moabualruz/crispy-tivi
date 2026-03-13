import 'dart:ui';

import 'package:crispy_tivi/features/player/presentation/providers/player_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late PlayerModeNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(playerModeProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('PlayerModeNotifier — valid transitions', () {
    test('idle -> preview succeeds', () {
      notifier.enterPreview(const Rect.fromLTWH(0, 0, 100, 56));
      expect(container.read(playerModeProvider).mode, PlayerMode.preview);
    });

    test('idle -> fullscreen succeeds', () {
      notifier.enterFullscreen();
      expect(container.read(playerModeProvider).mode, PlayerMode.fullscreen);
    });

    test('preview -> fullscreen succeeds', () {
      notifier.enterPreview(const Rect.fromLTWH(0, 0, 100, 56));
      notifier.enterFullscreen();
      expect(container.read(playerModeProvider).mode, PlayerMode.fullscreen);
    });

    test('preview -> background succeeds via exitToBackground', () {
      notifier.enterPreview(const Rect.fromLTWH(0, 0, 100, 56));
      notifier.exitToBackground();
      expect(container.read(playerModeProvider).mode, PlayerMode.background);
    });

    test('preview -> idle succeeds via setIdle', () {
      notifier.enterPreview(const Rect.fromLTWH(0, 0, 100, 56));
      notifier.setIdle();
      expect(container.read(playerModeProvider).mode, PlayerMode.idle);
    });

    test('fullscreen -> preview succeeds', () {
      notifier.enterPreview(
        const Rect.fromLTWH(0, 0, 100, 56),
        hostRoute: '/tv',
      );
      notifier.enterFullscreen();
      notifier.exitToPreview();
      expect(container.read(playerModeProvider).mode, PlayerMode.preview);
    });

    test('fullscreen -> background succeeds', () {
      notifier.enterFullscreen();
      notifier.exitToBackground();
      expect(container.read(playerModeProvider).mode, PlayerMode.background);
    });

    test('fullscreen -> idle succeeds via setIdle', () {
      notifier.enterFullscreen();
      notifier.setIdle();
      expect(container.read(playerModeProvider).mode, PlayerMode.idle);
    });

    test('background -> preview succeeds', () {
      notifier.enterFullscreen();
      notifier.exitToBackground();
      notifier.enterPreview(const Rect.fromLTWH(0, 0, 100, 56));
      expect(container.read(playerModeProvider).mode, PlayerMode.preview);
    });

    test('background -> fullscreen succeeds', () {
      notifier.enterFullscreen();
      notifier.exitToBackground();
      notifier.enterFullscreen();
      expect(container.read(playerModeProvider).mode, PlayerMode.fullscreen);
    });

    test('background -> idle succeeds via setIdle', () {
      notifier.enterFullscreen();
      notifier.exitToBackground();
      notifier.setIdle();
      expect(container.read(playerModeProvider).mode, PlayerMode.idle);
    });
  });

  group('PlayerModeNotifier — invalid transitions', () {
    test('idle -> background throws StateError', () {
      expect(() => notifier.exitToBackground(), throwsStateError);
    });
  });

  group('PlayerModeNotifier — setIdle always succeeds', () {
    test('from idle', () {
      notifier.setIdle();
      expect(container.read(playerModeProvider).mode, PlayerMode.idle);
    });

    test('from preview', () {
      notifier.enterPreview(const Rect.fromLTWH(0, 0, 100, 56));
      notifier.setIdle();
      expect(container.read(playerModeProvider).mode, PlayerMode.idle);
    });

    test('from fullscreen', () {
      notifier.enterFullscreen();
      notifier.setIdle();
      expect(container.read(playerModeProvider).mode, PlayerMode.idle);
    });

    test('from background', () {
      notifier.enterFullscreen();
      notifier.exitToBackground();
      notifier.setIdle();
      expect(container.read(playerModeProvider).mode, PlayerMode.idle);
    });
  });

  group('PlayerModeNotifier — enterFullscreen deduplication', () {
    test('same host route does not re-emit state', () {
      notifier.enterFullscreen(hostRoute: '/tv');
      final stateBefore = container.read(playerModeProvider);

      notifier.enterFullscreen(hostRoute: '/tv');
      final stateAfter = container.read(playerModeProvider);

      expect(identical(stateBefore, stateAfter), isTrue);
    });

    test('null host route does not re-emit when already fullscreen', () {
      notifier.enterFullscreen(hostRoute: '/tv');
      final stateBefore = container.read(playerModeProvider);

      notifier.enterFullscreen();
      final stateAfter = container.read(playerModeProvider);

      expect(identical(stateBefore, stateAfter), isTrue);
    });
  });
}
