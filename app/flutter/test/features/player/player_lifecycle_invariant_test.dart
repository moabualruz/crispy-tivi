import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/domain/player_lifecycle_coordinator.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_mode_provider.dart';

void main() {
  group('PlayerLifecycleCoordinator exhaustive invariants', () {
    // All 20 combinations: 4 modes x 5 statuses.
    for (final mode in PlayerMode.values) {
      for (final status in PlaybackStatus.values) {
        final label = '${mode.name} x ${status.name}';

        test('$label: showSurface implies mountSurface', () {
          final show = PlayerLifecycleCoordinator.shouldShowSurface(
            mode,
            status,
          );
          final mount = PlayerLifecycleCoordinator.shouldMountSurface(
            mode,
            status,
          );
          if (show) {
            expect(
              mount,
              isTrue,
              reason: '$label: showSurface=true but mountSurface=false',
            );
          }
        });

        test('$label: shouldShowMiniPlayer and shouldMountSurface '
            'are mutually exclusive', () {
          final mini = PlayerLifecycleCoordinator.shouldShowMiniPlayer(
            mode,
            status,
          );
          final mount = PlayerLifecycleCoordinator.shouldMountSurface(
            mode,
            status,
          );
          expect(
            mini && mount,
            isFalse,
            reason: '$label: both miniPlayer and mountSurface are true',
          );
        });

        test(
          '$label: invalid combinations never show mini-player or surface',
          () {
            final valid = PlayerLifecycleCoordinator.isValidCombination(
              mode,
              status,
            );
            if (!valid) {
              final mini = PlayerLifecycleCoordinator.shouldShowMiniPlayer(
                mode,
                status,
              );
              final show = PlayerLifecycleCoordinator.shouldShowSurface(
                mode,
                status,
              );
              expect(
                mini,
                isFalse,
                reason: '$label: invalid but shows mini-player',
              );
              expect(
                show,
                isFalse,
                reason: '$label: invalid but shows surface',
              );
            }
          },
        );
      }
    }

    group('idle mode never shows mini-player or mounts surface', () {
      for (final status in PlaybackStatus.values) {
        test('idle x ${status.name}', () {
          expect(
            PlayerLifecycleCoordinator.shouldShowMiniPlayer(
              PlayerMode.idle,
              status,
            ),
            isFalse,
            reason:
                'idle should never show mini-player (status=${status.name})',
          );
          expect(
            PlayerLifecycleCoordinator.shouldMountSurface(
              PlayerMode.idle,
              status,
            ),
            isFalse,
            reason: 'idle should never mount surface (status=${status.name})',
          );
        });
      }
    });

    group('truth table for key combinations', () {
      test('fullscreen + playing: mount=true, show=true, mini=false', () {
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
        expect(
          PlayerLifecycleCoordinator.shouldShowMiniPlayer(
            PlayerMode.fullscreen,
            PlaybackStatus.playing,
          ),
          isFalse,
        );
      });

      test('preview + buffering: mount=true, show=true, mini=false', () {
        expect(
          PlayerLifecycleCoordinator.shouldMountSurface(
            PlayerMode.preview,
            PlaybackStatus.buffering,
          ),
          isTrue,
        );
        expect(
          PlayerLifecycleCoordinator.shouldShowSurface(
            PlayerMode.preview,
            PlaybackStatus.buffering,
          ),
          isTrue,
        );
        expect(
          PlayerLifecycleCoordinator.shouldShowMiniPlayer(
            PlayerMode.preview,
            PlaybackStatus.buffering,
          ),
          isFalse,
        );
      });

      test('background + playing: mount=false, show=false, mini=true', () {
        expect(
          PlayerLifecycleCoordinator.shouldMountSurface(
            PlayerMode.background,
            PlaybackStatus.playing,
          ),
          isFalse,
        );
        expect(
          PlayerLifecycleCoordinator.shouldShowSurface(
            PlayerMode.background,
            PlaybackStatus.playing,
          ),
          isFalse,
        );
        expect(
          PlayerLifecycleCoordinator.shouldShowMiniPlayer(
            PlayerMode.background,
            PlaybackStatus.playing,
          ),
          isTrue,
        );
      });

      test('background + idle: mount=false, show=false, mini=false', () {
        expect(
          PlayerLifecycleCoordinator.shouldMountSurface(
            PlayerMode.background,
            PlaybackStatus.idle,
          ),
          isFalse,
        );
        expect(
          PlayerLifecycleCoordinator.shouldShowSurface(
            PlayerMode.background,
            PlaybackStatus.idle,
          ),
          isFalse,
        );
        expect(
          PlayerLifecycleCoordinator.shouldShowMiniPlayer(
            PlayerMode.background,
            PlaybackStatus.idle,
          ),
          isFalse,
        );
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
    });
  });
}
