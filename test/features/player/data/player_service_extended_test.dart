import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/features/player/data/'
    'os_media_session.dart';
import 'package:crispy_tivi/features/player/data/'
    'player_service.dart';
import 'package:crispy_tivi/features/player/domain/'
    'crispy_player.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'playback_state.dart'
    as app;
import 'package:crispy_tivi/features/player/domain/entities/'
    'stream_profile.dart';

// ── Mocks ──────────────────────────────────────────

class MockCrispyPlayer extends Mock implements CrispyPlayer {}

class _FakeOsMediaSession extends Fake implements OsMediaSession {
  @override
  Stream<MediaAction> get actions => const Stream.empty();
  @override
  Future<void> activate({
    required String title,
    String? artist,
    String? artUrl,
    Duration? duration,
  }) async {}
  @override
  Future<void> updatePlaybackState(bool isPlaying, Duration position) async {}
  @override
  Future<void> deactivate() async {}
  @override
  Future<void> dispose() async {}
}

final _noOpMediaSession = _FakeOsMediaSession();

// ── Helpers ────────────────────────────────────────

/// Stubs `player.open(...)` with all named parameters
/// matched so mocktail intercepts the real call from
/// [PlayerService.openMedia].
void _stubOpen(MockCrispyPlayer mp) {
  when(
    () => mp.open(
      any(),
      httpHeaders: any(named: 'httpHeaders'),
      extras: any(named: 'extras'),
      startPosition: any(named: 'startPosition'),
    ),
  ).thenAnswer((_) async {});
}

/// Creates a fully-stubbed [MockCrispyPlayer] with empty
/// streams unless overridden.
({MockCrispyPlayer player}) _setup({
  Stream<bool>? playing,
  Stream<Duration>? position,
  Stream<Duration>? duration,
  Stream<Duration>? buffer,
  Stream<bool>? buffering,
  Stream<double>? volume,
  Stream<double>? rate,
  Stream<String?>? error,
  Stream<CrispyTrackList>? tracks,
}) {
  final mp = MockCrispyPlayer();

  when(
    () => mp.playingStream,
  ).thenAnswer((_) => playing ?? const Stream.empty());
  when(
    () => mp.positionStream,
  ).thenAnswer((_) => position ?? const Stream.empty());
  when(
    () => mp.durationStream,
  ).thenAnswer((_) => duration ?? const Stream.empty());
  when(() => mp.bufferStream).thenAnswer((_) => buffer ?? const Stream.empty());
  when(
    () => mp.bufferingStream,
  ).thenAnswer((_) => buffering ?? const Stream.empty());
  when(() => mp.volumeStream).thenAnswer((_) => volume ?? const Stream.empty());
  when(() => mp.rateStream).thenAnswer((_) => rate ?? const Stream.empty());
  when(() => mp.errorStream).thenAnswer((_) => error ?? const Stream.empty());
  when(() => mp.tracksStream).thenAnswer((_) => tracks ?? const Stream.empty());
  when(() => mp.pause()).thenAnswer((_) async {});
  when(() => mp.dispose()).thenAnswer((_) async {});

  return (player: mp);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  // ── Error Handling & Reconnection ───────────────

  group('PlayerService — error handling', () {
    test('live stream error triggers auto-retry up to '
        'maxRetries', () async {
      final errorController = StreamController<String?>.broadcast();
      final s = _setup(error: errorController.stream);
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() {
        svc.dispose();
        errorController.close();
      });

      // Start a live stream.
      await svc.play('http://live.example.com/stream', isLive: true);

      // Emit errors — each should trigger a retry
      // up to maxRetries (3).
      errorController.add('Connection reset');
      await Future.delayed(Duration.zero);
      expect(svc.retryCount, 1);
      expect(svc.state.status, app.PlaybackStatus.buffering);
    });

    test('VOD stream error goes straight to error state', () async {
      final errorController = StreamController<String?>.broadcast();
      final s = _setup(error: errorController.stream);
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() {
        svc.dispose();
        errorController.close();
      });

      // Start a VOD stream.
      await svc.play('http://vod.example.com/movie.mp4', isLive: false);

      errorController.add('File not found');
      await Future.delayed(Duration.zero);

      expect(svc.state.status, app.PlaybackStatus.error);
      expect(svc.state.errorMessage, 'File not found');
      expect(svc.retryCount, 0);
    });

    test('live stream enters error state after '
        'maxRetries exceeded', () async {
      final errorController = StreamController<String?>.broadcast();
      final s = _setup(error: errorController.stream);
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() {
        svc.dispose();
        errorController.close();
      });

      // Start live.
      await svc.play('http://live.example.com/stream', isLive: true);

      // Exceed max retries (3).
      for (var i = 0; i <= PlayerServiceBase.maxRetries; i++) {
        errorController.add('Error $i');
        await Future.delayed(Duration.zero);
      }

      // After 4th error (0,1,2,3 — retry count
      // reaches 3 on 3rd error, 4th exceeds),
      // should be in error state.
      expect(svc.state.status, app.PlaybackStatus.error);
    });

    test('successful play after error resets retry count', () async {
      final errorController = StreamController<String?>.broadcast();
      final playingController = StreamController<bool>.broadcast();
      final s = _setup(
        error: errorController.stream,
        playing: playingController.stream,
      );
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() {
        svc.dispose();
        errorController.close();
        playingController.close();
      });

      // Start live, trigger an error.
      await svc.play('http://live.example.com/stream', isLive: true);
      errorController.add('timeout');
      await Future.delayed(Duration.zero);
      expect(svc.retryCount, 1);

      // Simulate successful playback.
      playingController.add(true);
      await Future.delayed(Duration.zero);
      expect(svc.retryCount, 0);
    });

    test('play() stores metadata for reconnection', () async {
      final s = _setup();
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.play(
        'http://live.example.com/ch1',
        isLive: true,
        channelName: 'Channel 1',
        channelLogoUrl: 'http://logo.com/ch1.png',
        currentProgram: 'Evening News',
        headers: {'User-Agent': 'CrispyTivi/1.0'},
      );

      expect(svc.state.channelName, 'Channel 1');
      expect(svc.state.channelLogoUrl, 'http://logo.com/ch1.png');
      expect(svc.state.currentProgram, 'Evening News');
      expect(svc.state.isLive, isTrue);
    });

    test('retry() replays last URL with same metadata', () async {
      final s = _setup();
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.play(
        'http://live.example.com/ch1',
        isLive: true,
        channelName: 'Ch 1',
      );
      await svc.retry();

      // open() should be called twice — initial
      // play + retry.
      verify(
        () => s.player.open(
          any(),
          httpHeaders: any(named: 'httpHeaders'),
          extras: any(named: 'extras'),
          startPosition: any(named: 'startPosition'),
        ),
      ).called(2);
    });

    test('retry() is no-op when no URL has been played', () async {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.retry();
      verifyNever(
        () => s.player.open(
          any(),
          httpHeaders: any(named: 'httpHeaders'),
          extras: any(named: 'extras'),
          startPosition: any(named: 'startPosition'),
        ),
      );
    });
  });

  // ── Audio Config Mixin ──────────────────────────

  group('PlayerService — audio config', () {
    test('default hwdec mode is "auto-safe"', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      expect(svc.hwdecMode, 'auto-safe');
    });

    test('setHwdecMode updates mode', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      svc.setHwdecMode('nvdec');
      expect(svc.hwdecMode, 'nvdec');
    });

    test('default stream profile is auto', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      expect(svc.streamProfile, StreamProfile.auto);
    });

    test('setStreamProfile updates profile', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      svc.setStreamProfile(StreamProfile.high);
      expect(svc.streamProfile, StreamProfile.high);
    });

    test('default audio output is "auto"', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      expect(svc.audioOutput, 'auto');
    });

    test('setAudioOutput updates output', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      svc.setAudioOutput('wasapi');
      expect(svc.audioOutput, 'wasapi');
    });

    test('default audio passthrough is disabled', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      expect(svc.audioPassthroughEnabled, isFalse);
      expect(svc.audioPassthroughCodecs, ['ac3', 'dts']);
    });

    test('setAudioPassthrough updates config', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      svc.setAudioPassthrough(true, ['ac3', 'eac3', 'truehd']);
      expect(svc.audioPassthroughEnabled, isTrue);
      expect(svc.audioPassthroughCodecs, ['ac3', 'eac3', 'truehd']);
    });

    test('audioPassthroughCodecs returns unmodifiable copy', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      expect(
        () => svc.audioPassthroughCodecs.add('test'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  // ── State Stream & Position Throttling ──────────

  group('PlayerService — state stream', () {
    test('play() emits buffering status immediately', () async {
      final s = _setup();
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      final states = <app.PlaybackStatus>[];
      final sub = svc.stateStream.listen((s) => states.add(s.status));

      await svc.play('http://example.com/video.mp4');
      await Future.delayed(Duration.zero);
      await sub.cancel();

      expect(states, contains(app.PlaybackStatus.buffering));
    });

    test('stop() resets state to default PlaybackState', () async {
      final s = _setup();
      _stubOpen(s.player);
      when(() => s.player.stop()).thenAnswer((_) async {});

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.play('http://example.com/video.mp4', channelName: 'Test');
      await svc.stop();

      expect(svc.state.status, app.PlaybackStatus.idle);
      expect(svc.state.channelName, isNull);
      expect(svc.state.retryCount, 0);
      expect(svc.state.isLive, isFalse);
    });

    test('stateStream emits on status changes', () async {
      final playingController = StreamController<bool>.broadcast();
      final s = _setup(playing: playingController.stream);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() {
        svc.dispose();
        playingController.close();
      });

      final statuses = <app.PlaybackStatus>[];
      final sub = svc.stateStream.listen((s) => statuses.add(s.status));

      playingController.add(true);
      await Future.delayed(Duration.zero);

      playingController.add(false);
      await Future.delayed(Duration.zero);

      await sub.cancel();

      expect(
        statuses,
        containsAll([app.PlaybackStatus.playing, app.PlaybackStatus.paused]),
      );
    });

    test('position-only updates are throttled to ~4 Hz', () {
      fakeAsync((async) {
        final posController = StreamController<Duration>.broadcast();
        final baseTime = DateTime(2026, 2, 22, 12);
        final s = _setup(position: posController.stream);

        final svc = PlayerService(
          player: s.player,
          clock: () => baseTime.add(async.elapsed),
          mediaSession: _noOpMediaSession,
        );

        final emittedPositions = <Duration>[];
        svc.stateStream.listen((s) => emittedPositions.add(s.position));

        // Emit 10 position updates in rapid
        // succession (faster than 250ms).
        for (var i = 0; i < 10; i++) {
          posController.add(Duration(seconds: i));
          async.elapse(const Duration(milliseconds: 50));
        }

        // Wait for flush timer.
        async.elapse(const Duration(milliseconds: 300));

        // Should have fewer than 10 emissions due
        // to throttling. The exact count depends on
        // the 250ms interval but should be < 10.
        expect(emittedPositions.length, lessThan(10));

        svc.dispose();
        posController.close();
      });
    });

    test('non-position state changes emit immediately '
        'even during throttle window', () {
      fakeAsync((async) {
        final posController = StreamController<Duration>.broadcast();
        final volController = StreamController<double>.broadcast();
        final baseTime = DateTime(2026, 2, 22, 12);
        final s = _setup(
          position: posController.stream,
          volume: volController.stream,
        );

        final svc = PlayerService(
          player: s.player,
          clock: () => baseTime.add(async.elapsed),
          mediaSession: _noOpMediaSession,
        );

        final volumes = <double>[];
        svc.stateStream.listen((s) => volumes.add(s.volume));

        // Emit position (starts throttle).
        posController.add(const Duration(seconds: 1));
        async.elapse(const Duration(milliseconds: 50));

        // Emit volume change — should bypass
        // throttle.
        volController.add(0.5);
        async.elapse(const Duration(milliseconds: 10));

        // Volume update should have emitted.
        expect(volumes, contains(0.5));

        svc.dispose();
        posController.close();
        volController.close();
      });
    });
  });

  // ── Buffering Status Logic ──────────────────────

  group('PlayerService — buffering transitions', () {
    test('buffering=true sets status to buffering', () {
      fakeAsync((async) {
        final bufferingController = StreamController<bool>.broadcast();
        final s = _setup(buffering: bufferingController.stream);

        final svc = PlayerService(
          player: s.player,
          mediaSession: _noOpMediaSession,
        );

        bufferingController.add(true);
        async.flushMicrotasks();
        // Debounced: 200ms stability window before
        // promoting to buffering (BUG-12 fix).
        async.elapse(const Duration(milliseconds: 200));

        expect(svc.state.status, app.PlaybackStatus.buffering);

        svc.dispose();
        bufferingController.close();
      });
    });

    test('buffering=false restores playing when player '
        'is playing', () {
      fakeAsync((async) {
        final bufferingController = StreamController<bool>.broadcast();
        final s = _setup(buffering: bufferingController.stream);
        when(() => s.player.isPlaying).thenReturn(true);

        final svc = PlayerService(
          player: s.player,
          mediaSession: _noOpMediaSession,
        );

        bufferingController.add(true);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 200));
        expect(svc.state.status, app.PlaybackStatus.buffering);

        bufferingController.add(false);
        async.flushMicrotasks();
        expect(svc.state.status, app.PlaybackStatus.playing);

        svc.dispose();
        bufferingController.close();
      });
    });
  });

  // ── Play / Pause / Stop Lifecycle ───────────────

  group('PlayerService — playback lifecycle', () {
    test('playOrPause delegates to player', () async {
      final s = _setup();
      when(() => s.player.playOrPause()).thenAnswer((_) async {});

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.playOrPause();
      verify(() => s.player.playOrPause()).called(1);
    });

    test('pause delegates to player', () async {
      final s = _setup();
      when(() => s.player.pause()).thenAnswer((_) async {});

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.pause();
      verify(() => s.player.pause()).called(1);
    });

    test('resume delegates to player.play()', () async {
      final s = _setup();
      when(() => s.player.play()).thenAnswer((_) async {});

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.resume();
      verify(() => s.player.play()).called(1);
    });

    test('seek delegates to player', () async {
      final s = _setup();
      when(() => s.player.seek(any())).thenAnswer((_) async {});

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.seek(const Duration(seconds: 30));
      verify(() => s.player.seek(const Duration(seconds: 30))).called(1);
    });

    test('stop() resets all live-stream bookkeeping', () async {
      final s = _setup();
      _stubOpen(s.player);
      when(() => s.player.stop()).thenAnswer((_) async {});

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.play(
        'http://live.example.com/stream',
        isLive: true,
        channelName: 'Ch1',
      );

      await svc.stop();

      expect(svc.state.status, app.PlaybackStatus.idle);
      expect(svc.state.channelName, isNull);
      expect(svc.retryCount, 0);
    });

    test('refresh() is equivalent to retry()', () async {
      final s = _setup();
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.play('http://example.com/video.mp4');
      await svc.refresh();

      // play() + refresh()/retry() = 2 opens
      verify(
        () => s.player.open(
          any(),
          httpHeaders: any(named: 'httpHeaders'),
          extras: any(named: 'extras'),
          startPosition: any(named: 'startPosition'),
        ),
      ).called(2);
    });
  });

  // ── Aspect Ratio Cycling (Stream Info) ──────────

  group('PlayerService — stream info mixin', () {
    test('initial aspect ratio is "Auto"', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      expect(svc.state.aspectRatioLabel, 'Auto');
    });

    test('cycleAspectRatio wraps from last to first', () {
      final s = _setup();
      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      // Cycle through all 5 ratios.
      final labels = <String>[];
      for (var i = 0; i < PlayerService.aspectRatios.length + 1; i++) {
        svc.cycleAspectRatio();
        labels.add(svc.state.aspectRatioLabel);
      }

      // Should wrap: Original → 16:9 → 4:3 → Fill
      // → Fit → Original
      expect(labels.last, labels.first);
    });
  });

  // ── Duration / Rate Streams ─────────────────────

  group('PlayerService — duration & rate streams', () {
    test('duration stream updates state.duration', () async {
      final durController = StreamController<Duration>.broadcast();
      final s = _setup(duration: durController.stream);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() {
        svc.dispose();
        durController.close();
      });

      durController.add(const Duration(minutes: 90));
      await Future.delayed(Duration.zero);

      expect(svc.state.duration, const Duration(minutes: 90));
    });

    test('rate stream updates state.speed', () async {
      final rateController = StreamController<double>.broadcast();
      final s = _setup(rate: rateController.stream);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() {
        svc.dispose();
        rateController.close();
      });

      rateController.add(2.0);
      await Future.delayed(Duration.zero);

      expect(svc.state.speed, 2.0);
    });

    test('volume stream updates state.volume', () async {
      final volController = StreamController<double>.broadcast();
      final s = _setup(volume: volController.stream);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() {
        svc.dispose();
        volController.close();
      });

      volController.add(0.75);
      await Future.delayed(Duration.zero);

      expect(svc.state.volume, 0.75);
    });
  });

  // ── Sleep Timer — Edge Cases ────────────────────

  group('PlayerService — sleep timer edge cases', () {
    test('replacing sleep timer cancels previous one', () {
      fakeAsync((async) {
        final baseTime = DateTime(2026, 2, 22, 12);
        final s = _setup();
        when(() => s.player.stop()).thenAnswer((_) async {});

        final svc = PlayerService(
          player: s.player,
          clock: () => baseTime.add(async.elapsed),
          mediaSession: _noOpMediaSession,
        );

        // Set 5s timer, then replace with 10s.
        svc.setSleepTimer(const Duration(seconds: 5));
        svc.setSleepTimer(const Duration(seconds: 10));

        // After 6s, first timer would have fired
        // but shouldn't because it was replaced.
        async.elapse(const Duration(seconds: 6));
        verifyNever(() => s.player.stop());

        // After 11s total, new timer should fire.
        async.elapse(const Duration(seconds: 5));
        verify(() => s.player.stop()).called(1);

        svc.dispose();
      });
    });

    test('sleepTimerEndTime is set when timer active', () {
      fakeAsync((async) {
        final baseTime = DateTime(2026, 2, 22, 12);
        final s = _setup();

        final svc = PlayerService(
          player: s.player,
          clock: () => baseTime.add(async.elapsed),
          mediaSession: _noOpMediaSession,
        );

        expect(svc.sleepTimerEndTime, isNull);

        svc.setSleepTimer(const Duration(minutes: 30));
        expect(svc.sleepTimerEndTime, isNotNull);

        svc.cancelSleepTimer();
        expect(svc.sleepTimerEndTime, isNull);

        svc.dispose();
      });
    });

    test('setSleepTimer(Duration.zero) cancels timer', () {
      fakeAsync((async) {
        final baseTime = DateTime(2026, 2, 22, 12);
        final s = _setup();
        when(() => s.player.stop()).thenAnswer((_) async {});

        final svc = PlayerService(
          player: s.player,
          clock: () => baseTime.add(async.elapsed),
          mediaSession: _noOpMediaSession,
        );

        svc.setSleepTimer(const Duration(seconds: 5));
        svc.setSleepTimer(Duration.zero);

        async.elapse(const Duration(seconds: 10));
        verifyNever(() => s.player.stop());
        expect(svc.state.sleepTimerRemaining, isNull);

        svc.dispose();
      });
    });
  });

  // ── Play State Metadata ─────────────────────────

  group('PlayerService — play metadata', () {
    test('play() sets isLive flag in state', () async {
      final s = _setup();
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.play('http://live.example.com/stream', isLive: true);

      expect(svc.state.isLive, isTrue);
    });

    test('play() defaults isLive to false', () async {
      final s = _setup();
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() => svc.dispose());

      await svc.play('http://vod.example.com/movie.mp4');

      expect(svc.state.isLive, isFalse);
    });

    test('play() clears previous error in state', () async {
      final errorController = StreamController<String?>.broadcast();
      final s = _setup(error: errorController.stream);
      _stubOpen(s.player);

      final svc = PlayerService(
        player: s.player,
        mediaSession: _noOpMediaSession,
      );
      addTearDown(() {
        svc.dispose();
        errorController.close();
      });

      await svc.play('http://vod.example.com/movie.mp4');

      // Force an error.
      errorController.add('Network error');
      await Future.delayed(Duration.zero);
      expect(svc.state.hasError, isTrue);

      // Play again — should clear error.
      await svc.play('http://vod.example.com/movie2.mp4');
      expect(svc.state.errorMessage, isNull);
      expect(svc.state.status, app.PlaybackStatus.buffering);
    });
  });
}
