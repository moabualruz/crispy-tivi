import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'playback_state.dart';

void main() {
  // ── Buffer Latency ──────────────────────────────

  group('PlaybackState — bufferLatency', () {
    test('returns Duration.zero for VOD streams', () {
      const state = PlaybackState(
        isLive: false,
        position: Duration(seconds: 10),
        bufferedPosition: Duration(seconds: 20),
      );
      expect(state.bufferLatency, Duration.zero);
    });

    test('returns diff for live streams', () {
      const state = PlaybackState(
        isLive: true,
        position: Duration(seconds: 10),
        bufferedPosition: Duration(seconds: 15),
      );
      expect(state.bufferLatency, const Duration(seconds: 5));
    });

    test('returns Duration.zero when diff is negative '
        '(live)', () {
      const state = PlaybackState(
        isLive: true,
        position: Duration(seconds: 20),
        bufferedPosition: Duration(seconds: 10),
      );
      expect(state.bufferLatency, Duration.zero);
    });

    test('returns Duration.zero when positions are '
        'equal (live)', () {
      const state = PlaybackState(
        isLive: true,
        position: Duration(seconds: 10),
        bufferedPosition: Duration(seconds: 10),
      );
      expect(state.bufferLatency, Duration.zero);
    });
  });

  // ── Buffer Progress ─────────────────────────────

  group('PlaybackState — bufferProgress', () {
    test('returns 0.0 when duration is zero', () {
      const state = PlaybackState(
        bufferedPosition: Duration(seconds: 10),
        duration: Duration.zero,
      );
      expect(state.bufferProgress, 0.0);
    });

    test('returns ratio of buffered to duration', () {
      const state = PlaybackState(
        bufferedPosition: Duration(seconds: 30),
        duration: Duration(seconds: 60),
      );
      expect(state.bufferProgress, 0.5);
    });

    test('clamps to 1.0 when buffered exceeds duration', () {
      const state = PlaybackState(
        bufferedPosition: Duration(seconds: 120),
        duration: Duration(seconds: 60),
      );
      expect(state.bufferProgress, 1.0);
    });
  });

  // ── Sleep Timer ─────────────────────────────────

  group('PlaybackState — hasSleepTimer', () {
    test('false when sleepTimerRemaining is null', () {
      const state = PlaybackState();
      expect(state.hasSleepTimer, isFalse);
    });

    test('false when sleepTimerRemaining is zero', () {
      const state = PlaybackState(sleepTimerRemaining: Duration.zero);
      expect(state.hasSleepTimer, isFalse);
    });

    test('true when sleepTimerRemaining is positive', () {
      const state = PlaybackState(sleepTimerRemaining: Duration(seconds: 120));
      expect(state.hasSleepTimer, isTrue);
    });
  });

  // ── copyWith — Sleep Timer ──────────────────────

  group('PlaybackState — copyWith sleep timer', () {
    test('clearSleepTimer nullifies remaining', () {
      const state = PlaybackState(sleepTimerRemaining: Duration(minutes: 30));
      final cleared = state.copyWith(clearSleepTimer: true);
      expect(cleared.sleepTimerRemaining, isNull);
    });

    test('clearSleepTimer takes precedence over new '
        'remaining', () {
      const state = PlaybackState(sleepTimerRemaining: Duration(minutes: 30));
      final cleared = state.copyWith(
        sleepTimerRemaining: const Duration(minutes: 10),
        clearSleepTimer: true,
      );
      expect(cleared.sleepTimerRemaining, isNull);
    });

    test('preserves sleepTimerRemaining when not '
        'cleared', () {
      const state = PlaybackState(sleepTimerRemaining: Duration(minutes: 30));
      final copy = state.copyWith(volume: 0.5);
      expect(copy.sleepTimerRemaining, const Duration(minutes: 30));
    });
  });

  // ── copyWith — Channel Metadata ─────────────────

  group('PlaybackState — copyWith channel metadata', () {
    test('updates channelName independently', () {
      const state = PlaybackState(
        channelName: 'Old Channel',
        channelLogoUrl: 'http://logo.com/old.png',
      );
      final copy = state.copyWith(channelName: 'New Channel');
      expect(copy.channelName, 'New Channel');
      expect(copy.channelLogoUrl, 'http://logo.com/old.png');
    });

    test('updates currentProgram independently', () {
      const state = PlaybackState(currentProgram: 'News');
      final copy = state.copyWith(currentProgram: 'Sports');
      expect(copy.currentProgram, 'Sports');
    });
  });

  // ── copyWith — Live ────────────────

  group('PlaybackState — copyWith live', () {
    test('updates isLive', () {
      const state = PlaybackState(isLive: false);
      final copy = state.copyWith(isLive: true);
      expect(copy.isLive, isTrue);
    });

    test('updates aspectRatioLabel', () {
      const state = PlaybackState(aspectRatioLabel: 'Auto');
      final copy = state.copyWith(aspectRatioLabel: '16:9');
      expect(copy.aspectRatioLabel, '16:9');
    });
  });

  // ── copyWith — Track Selection ──────────────────

  group('PlaybackState — copyWith track selection', () {
    test('updates selectedSubtitleTrackId', () {
      const state = PlaybackState(
        subtitleTracks: [
          SubtitleTrack(id: 0, title: 'English'),
          SubtitleTrack(id: 1, title: 'French'),
        ],
      );
      final copy = state.copyWith(selectedSubtitleTrackId: 1);
      expect(copy.selectedSubtitleTrackId, 1);
      expect(copy.subtitleTracks, hasLength(2));
    });

    test('replaces audioTracks list entirely', () {
      const state = PlaybackState(
        audioTracks: [AudioTrack(id: 0, title: 'English')],
      );
      final copy = state.copyWith(
        audioTracks: [
          const AudioTrack(id: 0, title: 'Japanese'),
          const AudioTrack(id: 1, title: 'Korean'),
        ],
      );
      expect(copy.audioTracks, hasLength(2));
      expect(copy.audioTracks[0].title, 'Japanese');
    });
  });

  // ── PlaybackStatus enum ─────────────────────────

  group('PlaybackStatus', () {
    test('has 5 values', () {
      expect(PlaybackStatus.values, hasLength(5));
    });

    test('values are idle, buffering, playing, paused, '
        'error', () {
      expect(
        PlaybackStatus.values,
        containsAll([
          PlaybackStatus.idle,
          PlaybackStatus.buffering,
          PlaybackStatus.playing,
          PlaybackStatus.paused,
          PlaybackStatus.error,
        ]),
      );
    });
  });

  // ── Default State Snapshot ──────────────────────

  group('PlaybackState — default snapshot', () {
    test('default state is idle with all safe values', () {
      const state = PlaybackState();
      expect(state.isPlaying, isFalse);
      expect(state.isBuffering, isFalse);
      expect(state.hasError, isFalse);
      expect(state.hasSleepTimer, isFalse);
      expect(state.progress, 0.0);
      expect(state.bufferProgress, 0.0);
      expect(state.bufferLatency, Duration.zero);
    });
  });
}
