import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';

void main() {
  group('PlaybackState', () {
    test('default constructor has sensible defaults', () {
      const state = PlaybackState();

      expect(state.status, PlaybackStatus.idle);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
      expect(state.volume, 1.0);
      expect(state.isMuted, isFalse);
      expect(state.speed, 1.0);
      expect(state.isFullscreen, isFalse);
      expect(state.isLive, isFalse);
      expect(state.aspectRatioLabel, 'Auto');
      expect(state.audioTracks, isEmpty);
      expect(state.subtitleTracks, isEmpty);
      expect(state.errorMessage, isNull);
      expect(state.retryCount, 0);
    });

    group('status getters', () {
      test('isPlaying reflects PlaybackStatus.playing', () {
        const state = PlaybackState(status: PlaybackStatus.playing);

        expect(state.isPlaying, isTrue);
        expect(state.isBuffering, isFalse);
        expect(state.hasError, isFalse);
      });

      test('isBuffering reflects PlaybackStatus.buffering', () {
        const state = PlaybackState(status: PlaybackStatus.buffering);

        expect(state.isBuffering, isTrue);
        expect(state.isPlaying, isFalse);
      });

      test('hasError reflects PlaybackStatus.error', () {
        const state = PlaybackState(
          status: PlaybackStatus.error,
          errorMessage: 'Network error',
        );

        expect(state.hasError, isTrue);
        expect(state.isPlaying, isFalse);
      });
    });

    group('progress', () {
      test('returns 0.0 when duration is zero (live)', () {
        const state = PlaybackState(
          position: Duration(seconds: 30),
          duration: Duration.zero,
        );

        expect(state.progress, 0.0);
      });

      test('calculates ratio of position to duration', () {
        const state = PlaybackState(
          position: Duration(seconds: 30),
          duration: Duration(seconds: 60),
        );

        expect(state.progress, 0.5);
      });

      test('clamps to 1.0 when position exceeds duration', () {
        const state = PlaybackState(
          position: Duration(seconds: 120),
          duration: Duration(seconds: 60),
        );

        expect(state.progress, 1.0);
      });

      test('returns 0.0 at the start', () {
        const state = PlaybackState(
          position: Duration.zero,
          duration: Duration(seconds: 60),
        );

        expect(state.progress, 0.0);
      });

      test('handles millisecond precision', () {
        const state = PlaybackState(
          position: Duration(milliseconds: 333),
          duration: Duration(milliseconds: 1000),
        );

        expect(state.progress, closeTo(0.333, 0.001));
      });
    });

    group('copyWith', () {
      test('preserves all fields when no params given', () {
        const original = PlaybackState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 10),
          duration: Duration(seconds: 60),
          volume: 0.8,
          isMuted: true,
          speed: 1.5,
          isLive: true,
          channelName: 'Test Channel',
          errorMessage: 'some error',
          retryCount: 2,
        );
        final copy = original.copyWith();

        expect(copy.status, original.status);
        expect(copy.position, original.position);
        expect(copy.duration, original.duration);
        expect(copy.volume, original.volume);
        expect(copy.isMuted, original.isMuted);
        expect(copy.speed, original.speed);
        expect(copy.isLive, original.isLive);
        expect(copy.channelName, original.channelName);
        expect(copy.errorMessage, original.errorMessage);
        expect(copy.retryCount, original.retryCount);
      });

      test('copyWith updates isMuted', () {
        const state = PlaybackState();
        final muted = state.copyWith(isMuted: true);

        expect(muted.isMuted, isTrue);
        // Volume preserved when muting.
        expect(muted.volume, 1.0);
      });

      test('copyWith preserves isMuted when unset', () {
        const state = PlaybackState(isMuted: true);
        final copy = state.copyWith(volume: 0.5);

        expect(copy.isMuted, isTrue);
        expect(copy.volume, 0.5);
      });

      test('clearError nullifies errorMessage', () {
        const state = PlaybackState(
          status: PlaybackStatus.error,
          errorMessage: 'Network error',
        );
        final cleared = state.copyWith(
          status: PlaybackStatus.playing,
          clearError: true,
        );

        expect(cleared.errorMessage, isNull);
        expect(cleared.status, PlaybackStatus.playing);
      });

      test('clearError takes precedence over new errorMessage', () {
        const state = PlaybackState(errorMessage: 'old error');
        final result = state.copyWith(
          errorMessage: 'new error',
          clearError: true,
        );

        expect(result.errorMessage, isNull);
      });

      test('updates audio and subtitle track selections', () {
        const state = PlaybackState(
          audioTracks: [
            AudioTrack(id: 0, title: 'English'),
            AudioTrack(id: 1, title: 'Spanish'),
          ],
        );
        final updated = state.copyWith(selectedAudioTrackId: 1);

        expect(updated.selectedAudioTrackId, 1);
        expect(updated.audioTracks.length, 2);
      });
    });
  });

  group('AudioTrack', () {
    test('stores id, title, and optional language', () {
      const track = AudioTrack(id: 1, title: 'English', language: 'eng');

      expect(track.id, 1);
      expect(track.title, 'English');
      expect(track.language, 'eng');
    });

    test('language defaults to null', () {
      const track = AudioTrack(id: 0, title: 'Default');

      expect(track.language, isNull);
    });
  });

  group('SubtitleTrack', () {
    test('stores id, title, and optional language', () {
      const track = SubtitleTrack(id: 2, title: 'French', language: 'fre');

      expect(track.id, 2);
      expect(track.title, 'French');
      expect(track.language, 'fre');
    });
  });
}
