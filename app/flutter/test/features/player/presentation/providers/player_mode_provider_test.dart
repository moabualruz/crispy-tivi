import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_mode_provider.dart';

void main() {
  group('PlayerModeNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is idle', () {
      final state = container.read(playerModeProvider);
      expect(state.mode, equals(PlayerMode.idle));
      expect(state.previewRect, isNull);
      expect(state.hostRoute, isNull);
      expect(state.currentRoute, isNull);
      expect(state.originRoute, isNull);
    });

    test('enterPreview sets preview state', () {
      final notifier = container.read(playerModeProvider.notifier);
      final rect = const Rect.fromLTWH(0, 0, 100, 100);

      notifier.enterPreview(rect, hostRoute: '/test');

      final state = container.read(playerModeProvider);
      expect(state.mode, equals(PlayerMode.preview));
      expect(state.previewRect, equals(rect));
      expect(state.hostRoute, equals('/test'));
    });

    test('enterFullscreen snapshots state', () {
      final notifier = container.read(playerModeProvider.notifier);
      notifier.updateCurrentRoute('/home');
      notifier.enterFullscreen(hostRoute: '/player');

      final state = container.read(playerModeProvider);
      expect(state.mode, equals(PlayerMode.fullscreen));
      expect(state.hostRoute, equals('/player'));
      expect(state.originRoute, equals('/home'));
    });

    test('exitToPreview restores preview', () {
      final notifier = container.read(playerModeProvider.notifier);
      final rect = const Rect.fromLTWH(0, 0, 100, 100);

      notifier.enterPreview(rect, hostRoute: '/test');
      notifier.updateCurrentRoute('/test/home'); // Must be inside hostRoute
      notifier.enterFullscreen(hostRoute: '/player');

      notifier.exitToPreview();

      final state = container.read(playerModeProvider);
      expect(state.mode, equals(PlayerMode.preview));
      expect(state.originRoute, isNull);
    });

    test('exitToBackground state', () {
      final notifier = container.read(playerModeProvider.notifier);

      // Must be in a non-idle mode first (idle -> background is invalid).
      notifier.enterFullscreen();
      notifier.exitToBackground();

      final state = container.read(playerModeProvider);
      expect(state.mode, equals(PlayerMode.background));
    });

    test('setIdle cleanly stops everything', () {
      final notifier = container.read(playerModeProvider.notifier);
      notifier.enterPreview(const Rect.fromLTWH(0, 0, 100, 100));
      notifier.setIdle();

      final state = container.read(playerModeProvider);
      expect(state.mode, equals(PlayerMode.idle));
      expect(state.previewRect, isNull);
    });

    test(
      'exitToPreview with screenSize but non-preview hostRoute → background',
      () {
        final notifier = container.read(playerModeProvider.notifier);
        notifier.enterFullscreen(hostRoute: '/vods/details');
        notifier.exitToPreview(screenSize: const Size(1920, 1080));

        final state = container.read(playerModeProvider);
        expect(state.mode, equals(PlayerMode.background));
      },
    );

    test(
      'exitToPreview with screenSize and TV hostRoute → preview (mini PiP)',
      () {
        final notifier = container.read(playerModeProvider.notifier);
        notifier.enterFullscreen(hostRoute: '/tv');
        notifier.exitToPreview(screenSize: const Size(1920, 1080));

        final state = container.read(playerModeProvider);
        expect(state.mode, equals(PlayerMode.preview));
        expect(state.previewRect, isNotNull);
      },
    );

    test(
      'exitToPreview with screenSize and EPG hostRoute → preview (mini PiP)',
      () {
        final notifier = container.read(playerModeProvider.notifier);
        notifier.enterFullscreen(hostRoute: '/epg');
        notifier.exitToPreview(screenSize: const Size(1920, 1080));

        final state = container.read(playerModeProvider);
        expect(state.mode, equals(PlayerMode.preview));
        expect(state.previewRect, isNotNull);
      },
    );

    test('stopPreviewIfLeavingRoute handles navigation leaving', () {
      bool playbackStopped = false;
      final notifier = container.read(playerModeProvider.notifier);

      notifier.enterPreview(
        const Rect.fromLTWH(0, 0, 100, 100),
        hostRoute: '/host',
      );
      notifier.updateCurrentRoute('/host');

      notifier.stopPreviewIfLeavingRoute(
        '/new',
        stopPlayback: () {
          playbackStopped = true;
        },
      );

      final state = container.read(playerModeProvider);
      expect(playbackStopped, isTrue);
      // Wait for it to be reset since updateCurrentRoute internally zeroes it out
      expect(state.mode, equals(PlayerMode.idle));
    });
  });
}
