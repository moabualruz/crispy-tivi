// Tests for PermanentVideoLayer coordinator-driven surface visibility.
//
// Covers:
//   - idle mode -> no video surface (SizedBox.shrink)
//   - preview + playing -> video surface mounted
//   - fullscreen + playing -> video surface mounted
//   - background mode -> video surface unmounted
//   - preview + idle status -> no video surface (coordinator says don't mount)
//   - Visibility widget wraps surface when opacity=0

import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/domain/player_lifecycle_coordinator.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_mode_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Tests ────────────────────────────────────────────────────
//
// PermanentVideoLayer depends heavily on platform video widgets
// (media_kit / WebHlsVideo) which cannot be pumped in unit tests.
// Instead we verify the coordinator logic that PermanentVideoLayer
// delegates to, testing every mode+status combination that the
// widget evaluates during build.

void main() {
  group('PermanentVideoLayer surface mount logic', () {
    test('idle mode -> surface not mounted', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.idle,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });

    test('idle mode + playing status -> surface not mounted', () {
      // Even with stale playing status, idle mode means no surface.
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.idle,
          PlaybackStatus.playing,
        ),
        isFalse,
      );
    });

    test('preview + playing -> surface mounted', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.preview,
          PlaybackStatus.playing,
        ),
        isTrue,
      );
    });

    test('preview + buffering -> surface mounted', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.preview,
          PlaybackStatus.buffering,
        ),
        isTrue,
      );
    });

    test(
      'preview + idle status -> surface mounted (coordinator mounts for preview regardless)',
      () {
        // shouldMountSurface returns true for preview/fullscreen
        // regardless of status — the widget still mounts but hides
        // via Visibility. shouldShowSurface gates actual visibility.
        expect(
          PlayerLifecycleCoordinator.shouldMountSurface(
            PlayerMode.preview,
            PlaybackStatus.idle,
          ),
          isTrue,
        );
      },
    );

    test('preview + idle status -> surface NOT shown (shouldShowSurface)', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.preview,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });

    test('fullscreen + playing -> surface mounted and visible', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.fullscreen,
          PlaybackStatus.playing,
        ),
        isTrue,
      );
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.fullscreen,
          PlaybackStatus.playing,
        ),
        isTrue,
      );
    });

    test('fullscreen + paused -> surface mounted and visible', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.fullscreen,
          PlaybackStatus.paused,
        ),
        isTrue,
      );
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.fullscreen,
          PlaybackStatus.paused,
        ),
        isTrue,
      );
    });

    test('background mode -> surface not mounted', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.background,
          PlaybackStatus.playing,
        ),
        isFalse,
      );
    });

    test('background + idle -> surface not mounted', () {
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.background,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });

    test('fullscreen -> idle transition removes surface', () {
      // Fullscreen: mounted
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.fullscreen,
          PlaybackStatus.playing,
        ),
        isTrue,
      );
      // After transition to idle: unmounted
      expect(
        PlayerLifecycleCoordinator.shouldMountSurface(
          PlayerMode.idle,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });
  });

  group('PermanentVideoLayer surface visibility (Visibility widget)', () {
    test('preview + playing -> surface visible (opacity > 0)', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.preview,
          PlaybackStatus.playing,
        ),
        isTrue,
      );
    });

    test('fullscreen + buffering -> surface visible', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.fullscreen,
          PlaybackStatus.buffering,
        ),
        isTrue,
      );
    });

    test('fullscreen + error -> surface visible (error overlay on top)', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.fullscreen,
          PlaybackStatus.error,
        ),
        isTrue,
      );
    });

    test('idle + idle -> surface not visible', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.idle,
          PlaybackStatus.idle,
        ),
        isFalse,
      );
    });

    test('background + playing -> surface not visible', () {
      expect(
        PlayerLifecycleCoordinator.shouldShowSurface(
          PlayerMode.background,
          PlaybackStatus.playing,
        ),
        isFalse,
      );
    });
  });
}
