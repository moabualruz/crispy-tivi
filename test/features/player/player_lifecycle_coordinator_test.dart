import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/domain/player_lifecycle_coordinator.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_mode_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerLifecycleCoordinator — isValidCombination', () {
    test('idle mode + any status is valid', () {
      for (final status in PlaybackStatus.values) {
        expect(
          PlayerLifecycleCoordinator.isValidCombination(
            PlayerMode.idle,
            status,
          ),
          isTrue,
          reason: 'idle + $status should be valid',
        );
      }
    });

    test('background mode + any status is valid', () {
      for (final status in PlaybackStatus.values) {
        expect(
          PlayerLifecycleCoordinator.isValidCombination(
            PlayerMode.background,
            status,
          ),
          isTrue,
          reason: 'background + $status should be valid',
        );
      }
    });

    test('fullscreen + idle is invalid', () {
      expect(
        PlayerLifecycleCoordinator.isValidCombination(
          PlayerMode.fullscreen,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });

    test('preview + idle is invalid', () {
      expect(
        PlayerLifecycleCoordinator.isValidCombination(
          PlayerMode.preview,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });

    test('fullscreen + playing is valid', () {
      expect(
        PlayerLifecycleCoordinator.isValidCombination(
          PlayerMode.fullscreen,
          PlaybackStatus.playing,
        ),
        isTrue,
      );
    });

    test('preview + buffering is valid', () {
      expect(
        PlayerLifecycleCoordinator.isValidCombination(
          PlayerMode.preview,
          PlaybackStatus.buffering,
        ),
        isTrue,
      );
    });

    test('fullscreen + error is valid', () {
      expect(
        PlayerLifecycleCoordinator.isValidCombination(
          PlayerMode.fullscreen,
          PlaybackStatus.error,
        ),
        isTrue,
      );
    });
  });

  group('PlayerLifecycleCoordinator — shouldShowMiniPlayer', () {
    test('true for background + playing', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowMiniPlayer(
          PlayerMode.background,
          PlaybackStatus.playing,
        ),
        isTrue,
      );
    });

    test('true for background + paused', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowMiniPlayer(
          PlayerMode.background,
          PlaybackStatus.paused,
        ),
        isTrue,
      );
    });

    test('true for background + buffering', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowMiniPlayer(
          PlayerMode.background,
          PlaybackStatus.buffering,
        ),
        isTrue,
      );
    });

    test('false for background + idle', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowMiniPlayer(
          PlayerMode.background,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });

    test('false for background + error', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowMiniPlayer(
          PlayerMode.background,
          PlaybackStatus.error,
        ),
        isFalse,
      );
    });

    test('false for non-background modes', () {
      for (final mode in [
        PlayerMode.idle,
        PlayerMode.preview,
        PlayerMode.fullscreen,
      ]) {
        expect(
          PlayerLifecycleCoordinator.shouldShowMiniPlayer(
            mode,
            PlaybackStatus.playing,
          ),
          isFalse,
          reason: '$mode + playing should not show mini player',
        );
      }
    });
  });

  group('PlayerLifecycleCoordinator — shouldMountSurface', () {
    test('true for preview', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.preview,
          PlaybackStatus.playing,
        ),
        isTrue,
      );
    });

    test('true for fullscreen', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.fullscreen,
          PlaybackStatus.playing,
        ),
        isTrue,
      );
    });

    test('false for idle', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.idle,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });

    test('false for background', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.background,
          PlaybackStatus.playing,
        ),
        isFalse,
      );
    });
  });

  group('PlayerLifecycleCoordinator — shouldShowSurface', () {
    test('true for preview + playing', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.preview,
          PlaybackStatus.playing,
        ),
        isTrue,
      );
    });

    test('false for preview + idle', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.preview,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });

    test('true for fullscreen + buffering', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.fullscreen,
          PlaybackStatus.buffering,
        ),
        isTrue,
      );
    });

    test('false for idle + idle', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.idle,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });
  });
}
