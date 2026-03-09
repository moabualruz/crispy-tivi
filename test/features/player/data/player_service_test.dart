import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';

// Mocks
class MockCrispyPlayer extends Mock implements CrispyPlayer {}

/// Helper to stub all CrispyPlayer streams with empty defaults.
void _stubEmptyStreams(MockCrispyPlayer mock) {
  when(() => mock.playingStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.positionStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.durationStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.bufferStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.bufferingStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.volumeStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.rateStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.errorStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.tracksStream).thenAnswer((_) => const Stream.empty());

  when(() => mock.pause()).thenAnswer((_) async {});
  when(() => mock.dispose()).thenAnswer((_) async {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  group('PlayerService', () {
    late MockCrispyPlayer mockPlayer;
    late PlayerService playerService;

    setUp(() {
      mockPlayer = MockCrispyPlayer();
      _stubEmptyStreams(mockPlayer);
      playerService = PlayerService(player: mockPlayer);
    });

    tearDown(() {
      playerService.dispose();
    });

    test('cycleAspectRatio cycles through expected ratios', () async {
      expect(playerService.state.aspectRatioLabel, 'Auto');

      playerService.cycleAspectRatio();
      expect(playerService.state.aspectRatioLabel, 'Original');

      playerService.cycleAspectRatio();
      expect(playerService.state.aspectRatioLabel, '16:9');

      playerService.cycleAspectRatio();
      expect(playerService.state.aspectRatioLabel, '4:3');

      playerService.cycleAspectRatio();
      expect(playerService.state.aspectRatioLabel, 'Fill');

      playerService.cycleAspectRatio();
      expect(playerService.state.aspectRatioLabel, 'Fit');

      playerService.cycleAspectRatio();
      expect(playerService.state.aspectRatioLabel, 'Original');
    });

    test('Sleep timer stops playback after duration', () {
      fakeAsync((async) {
        final baseTime = DateTime(2026, 2, 20, 12);
        final svc = PlayerService(
          player: mockPlayer,
          clock: () => baseTime.add(async.elapsed),
        );
        addTearDown(() => svc.dispose());
        when(() => mockPlayer.stop()).thenAnswer((_) async {});

        svc.setSleepTimer(const Duration(seconds: 5));

        verifyNever(() => mockPlayer.stop());

        // Advance past the timer duration.
        async.elapse(const Duration(seconds: 6));

        verify(() => mockPlayer.stop()).called(1);
      });
    });

    test('Sleep timer cancellation avoids stop', () {
      fakeAsync((async) {
        final baseTime = DateTime(2026, 2, 20, 12);
        final svc = PlayerService(
          player: mockPlayer,
          clock: () => baseTime.add(async.elapsed),
        );
        addTearDown(() => svc.dispose());
        when(() => mockPlayer.stop()).thenAnswer((_) async {});

        svc.setSleepTimer(const Duration(seconds: 5));
        svc.cancelSleepTimer();

        // Advance past original duration.
        async.elapse(const Duration(seconds: 10));

        verifyNever(() => mockPlayer.stop());
      });
    });

    test('Sleep timer emits countdown via state stream', () {
      fakeAsync((async) {
        final baseTime = DateTime(2026, 2, 20, 12);
        final svc = PlayerService(
          player: mockPlayer,
          clock: () => baseTime.add(async.elapsed),
        );
        addTearDown(() => svc.dispose());
        when(() => mockPlayer.stop()).thenAnswer((_) async {});

        svc.setSleepTimer(const Duration(seconds: 3));

        // Initial: 3s remaining.
        expect(svc.state.sleepTimerRemaining, const Duration(seconds: 3));

        // After 1 tick, ~2s remaining.
        async.elapse(const Duration(seconds: 1));
        final remaining = svc.state.sleepTimerRemaining;
        expect(remaining, isNotNull);
        expect(remaining!.inSeconds, lessThanOrEqualTo(2));
      });
    });

    test('cancelSleepTimer clears remaining from state', () {
      fakeAsync((async) {
        final baseTime = DateTime(2026, 2, 20, 12);
        final svc = PlayerService(
          player: mockPlayer,
          clock: () => baseTime.add(async.elapsed),
        );
        addTearDown(() => svc.dispose());

        svc.setSleepTimer(const Duration(seconds: 30));
        expect(svc.state.sleepTimerRemaining, isNotNull);

        svc.cancelSleepTimer();
        expect(svc.state.sleepTimerRemaining, isNull);
      });
    });

    test('Sleep timer hasSleepTimer getter works', () {
      fakeAsync((async) {
        final baseTime = DateTime(2026, 2, 20, 12);
        final svc = PlayerService(
          player: mockPlayer,
          clock: () => baseTime.add(async.elapsed),
        );
        addTearDown(() => svc.dispose());
        when(() => mockPlayer.stop()).thenAnswer((_) async {});

        svc.setSleepTimer(const Duration(seconds: 5));

        // After 3s — still active.
        async.elapse(const Duration(seconds: 3));
        expect(svc.state.hasSleepTimer, isTrue);
        verifyNever(() => mockPlayer.stop());

        // After 5+ seconds — triggers stop.
        async.elapse(const Duration(seconds: 3));
        verify(() => mockPlayer.stop()).called(1);
        expect(svc.state.hasSleepTimer, isFalse);
      });
    });
  });

  group('PlayerService — volume / mute', () {
    late MockCrispyPlayer mockPlayer;
    late PlayerService playerService;

    setUp(() {
      mockPlayer = MockCrispyPlayer();
      _stubEmptyStreams(mockPlayer);
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

      playerService = PlayerService(player: mockPlayer);
    });

    tearDown(() {
      playerService.dispose();
    });

    test('setVolume delegates to CrispyPlayer '
        'with 0.0-1.0 range', () async {
      await playerService.setVolume(0.5);
      verify(() => mockPlayer.setVolume(0.5)).called(1);
    });

    test('setVolume clamps value to 0.0-1.0', () async {
      await playerService.setVolume(1.5);
      verify(() => mockPlayer.setVolume(1.0)).called(1);

      await playerService.setVolume(-0.5);
      verify(() => mockPlayer.setVolume(0.0)).called(1);
    });

    test('toggleMute on native toggles volume to 0 '
        'and back', () async {
      // Set volume to 0.7 first.
      await playerService.setVolume(0.7);

      // Mute — should set volume to 0.
      playerService.toggleMute();
      verify(() => mockPlayer.setVolume(0.0)).called(1);

      // Unmute — should restore to 0.7.
      playerService.toggleMute();
      verify(() => mockPlayer.setVolume(0.7)).called(1);
    });

    test('default isMuted is false', () {
      expect(playerService.state.isMuted, isFalse);
    });
  });

  group('PlayerService — setSpeed', () {
    late MockCrispyPlayer mockPlayer;
    late PlayerService playerService;

    setUp(() {
      mockPlayer = MockCrispyPlayer();
      _stubEmptyStreams(mockPlayer);
      when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});

      playerService = PlayerService(player: mockPlayer);
    });

    tearDown(() {
      playerService.dispose();
    });

    test('calls player.setRate with correct value', () async {
      await playerService.setSpeed(1.5);
      verify(() => mockPlayer.setRate(1.5)).called(1);
    });

    test('clamps speed to valid range', () async {
      await playerService.setSpeed(0.1);
      verify(() => mockPlayer.setRate(0.25)).called(1);

      await playerService.setSpeed(10.0);
      verify(() => mockPlayer.setRate(4.0)).called(1);
    });

    test('is a no-op when stream is live', () async {
      when(
        () => mockPlayer.open(
          any(),
          httpHeaders: any(named: 'httpHeaders'),
          extras: any(named: 'extras'),
          startPosition: any(named: 'startPosition'),
        ),
      ).thenAnswer((_) async {});

      await playerService.play('http://live.example.com/stream', isLive: true);

      await playerService.setSpeed(2.0);
      verifyNever(() => mockPlayer.setRate(any()));
    });

    test('play() resets speed to 1.0 in state', () async {
      when(
        () => mockPlayer.open(
          any(),
          httpHeaders: any(named: 'httpHeaders'),
          extras: any(named: 'extras'),
          startPosition: any(named: 'startPosition'),
        ),
      ).thenAnswer((_) async {});

      // Set speed to 2x first.
      await playerService.setSpeed(2.0);

      // Start a new VOD — speed should reset.
      await playerService.play('http://vod.example.com/movie.mp4');

      expect(playerService.state.speed, 1.0);
    });
  });

  group('PlayerService — UI Heartbeat Watchdog', () {
    late MockCrispyPlayer mockPlayer;
    late StreamController<bool> playingController;

    MockCrispyPlayer createMockPlayer() {
      mockPlayer = MockCrispyPlayer();
      playingController = StreamController<bool>.broadcast();

      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => playingController.stream);
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.bufferStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.bufferingStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.volumeStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockPlayer.rateStream).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.errorStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.tracksStream,
      ).thenAnswer((_) => const Stream.empty());

      when(() => mockPlayer.pause()).thenAnswer((_) async {});
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
      when(() => mockPlayer.play()).thenAnswer((_) async {});

      return mockPlayer;
    }

    test('wasAutoPausedByWatchdog starts false', () {
      final mp = createMockPlayer();
      final svc = PlayerService(player: mp);
      addTearDown(() => svc.dispose());

      expect(svc.wasAutoPausedByWatchdog, isFalse);
    });

    test('startWatchdog resets auto-pause flag', () {
      final mp = createMockPlayer();
      final svc = PlayerService(player: mp);
      addTearDown(() => svc.dispose());

      svc.startWatchdog();
      expect(svc.wasAutoPausedByWatchdog, isFalse);

      svc.stopWatchdog();
    });

    test('stopWatchdog resets auto-pause flag', () {
      final mp = createMockPlayer();
      final svc = PlayerService(player: mp);
      addTearDown(() => svc.dispose());

      svc.startWatchdog();
      svc.stopWatchdog();
      expect(svc.wasAutoPausedByWatchdog, isFalse);
    });

    test('watchdog detects freeze and auto-pauses when '
        'elapsed > 5s while playing', () async {
      final mp = createMockPlayer();

      var callCount = 0;
      final baseTime = DateTime(2026, 2, 20, 12, 0, 0);
      DateTime fakeClock() {
        callCount++;
        if (callCount == 1) return baseTime;
        return baseTime.add(const Duration(seconds: 10));
      }

      final svc = PlayerService(player: mp, clock: fakeClock);
      addTearDown(() => svc.dispose());

      playingController.add(true);
      await Future.delayed(Duration.zero);

      expect(svc.state.isPlaying, isTrue);

      svc.startWatchdog();

      await Future.delayed(const Duration(milliseconds: 2200));

      expect(svc.wasAutoPausedByWatchdog, isTrue);
      verify(() => mp.pause()).called(1);

      svc.stopWatchdog();
    });

    test('watchdog does NOT pause when elapsed < 5s', () async {
      final mp = createMockPlayer();

      final svc = PlayerService(player: mp);
      addTearDown(() => svc.dispose());

      playingController.add(true);
      await Future.delayed(Duration.zero);

      svc.startWatchdog();

      await Future.delayed(const Duration(milliseconds: 2200));

      expect(svc.wasAutoPausedByWatchdog, isFalse);
      verifyNever(() => mp.pause());

      svc.stopWatchdog();
    });

    test('resumeFromWatchdog resumes when auto-paused', () async {
      final mp = createMockPlayer();

      var callCount = 0;
      final baseTime = DateTime(2026, 2, 20, 12, 0, 0);
      DateTime fakeClock() {
        callCount++;
        if (callCount == 1) return baseTime;
        return baseTime.add(const Duration(seconds: 10));
      }

      final svc = PlayerService(player: mp, clock: fakeClock);
      addTearDown(() => svc.dispose());

      playingController.add(true);
      await Future.delayed(Duration.zero);

      svc.startWatchdog();

      await Future.delayed(const Duration(milliseconds: 2200));

      expect(svc.wasAutoPausedByWatchdog, isTrue);

      svc.resumeFromWatchdog();

      expect(svc.wasAutoPausedByWatchdog, isFalse);
      verify(() => mp.play()).called(1);

      svc.stopWatchdog();
    });

    test('resumeFromWatchdog does nothing when not '
        'auto-paused', () {
      final mp = createMockPlayer();
      final svc = PlayerService(player: mp);
      addTearDown(() => svc.dispose());

      svc.resumeFromWatchdog();
      verifyNever(() => mp.play());
    });

    test('stop() cancels watchdog', () async {
      final mp = createMockPlayer();
      when(() => mp.stop()).thenAnswer((_) async {});

      final svc = PlayerService(player: mp);
      addTearDown(() => svc.dispose());

      svc.startWatchdog();
      await svc.stop();

      expect(svc.wasAutoPausedByWatchdog, isFalse);
    });
  });

  group('PlayerService — track selection', () {
    late MockCrispyPlayer mockPlayer;
    late StreamController<CrispyTrackList> tracksController;
    late PlayerService playerService;

    setUp(() {
      mockPlayer = MockCrispyPlayer();
      tracksController = StreamController<CrispyTrackList>.broadcast();

      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.bufferStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.bufferingStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.volumeStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockPlayer.rateStream).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.errorStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.tracksStream,
      ).thenAnswer((_) => tracksController.stream);

      when(() => mockPlayer.pause()).thenAnswer((_) async {});
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      playerService = PlayerService(player: mockPlayer);
    });

    tearDown(() {
      playerService.dispose();
      tracksController.close();
    });

    test('populates audioTracks from CrispyPlayer '
        'tracksStream', () async {
      tracksController.add(
        const CrispyTrackList(
          audio: [
            CrispyAudioTrack(index: 0, title: 'English', language: 'en'),
            CrispyAudioTrack(index: 1, title: 'Spanish', language: 'es'),
          ],
          subtitle: [],
        ),
      );

      await Future.delayed(Duration.zero);

      expect(playerService.state.audioTracks, hasLength(2));
      expect(playerService.state.audioTracks[0].title, 'English');
      expect(playerService.state.audioTracks[1].title, 'Spanish');
    });

    test('subtitleTracks empty when stream has none', () async {
      tracksController.add(
        const CrispyTrackList(
          audio: [CrispyAudioTrack(index: 0, title: 'English', language: 'en')],
          subtitle: [],
        ),
      );

      await Future.delayed(Duration.zero);

      expect(playerService.state.subtitleTracks, isEmpty);
    });

    test('populates subtitleTracks from CrispyPlayer '
        'tracksStream', () async {
      tracksController.add(
        const CrispyTrackList(
          audio: [],
          subtitle: [
            CrispySubtitleTrack(index: 0, title: 'English', language: 'en'),
            CrispySubtitleTrack(index: 1, title: 'French', language: 'fr'),
          ],
        ),
      );

      await Future.delayed(Duration.zero);

      expect(playerService.state.subtitleTracks, hasLength(2));
      expect(playerService.state.subtitleTracks[0].title, 'English');
      expect(playerService.state.subtitleTracks[1].title, 'French');
    });

    test('setAudioTrack delegates to CrispyPlayer', () async {
      when(() => mockPlayer.setAudioTrack(any())).thenAnswer((_) async {});

      await playerService.setAudioTrack(1);

      verify(() => mockPlayer.setAudioTrack(1)).called(1);
      expect(playerService.state.selectedAudioTrackId, 1);
    });

    test('setSubtitleTrack(-1) disables subtitles', () async {
      when(() => mockPlayer.setSubtitleTrack(any())).thenAnswer((_) async {});

      await playerService.setSubtitleTrack(-1);

      verify(() => mockPlayer.setSubtitleTrack(-1)).called(1);
      expect(playerService.state.selectedSubtitleTrackId, -1);
    });

    test('setSubtitleTrack selects correct track', () async {
      when(() => mockPlayer.setSubtitleTrack(any())).thenAnswer((_) async {});

      await playerService.setSubtitleTrack(0);

      verify(() => mockPlayer.setSubtitleTrack(0)).called(1);
      expect(playerService.state.selectedSubtitleTrackId, 0);
    });
  });

  group('PlayerService — fullscreen state', () {
    late MockCrispyPlayer mockPlayer;
    late PlayerService playerService;

    setUp(() {
      mockPlayer = MockCrispyPlayer();
      _stubEmptyStreams(mockPlayer);
      playerService = PlayerService(player: mockPlayer);
    });

    tearDown(() {
      playerService.dispose();
    });

    test('default isFullscreen is false', () {
      expect(playerService.state.isFullscreen, isFalse);
    });

    test('setFullscreen(true) updates state to true', () async {
      playerService.setFullscreen(true);

      expect(playerService.state.isFullscreen, isTrue);
    });

    test('setFullscreen(false) updates state to false', () async {
      playerService.setFullscreen(true);
      expect(playerService.state.isFullscreen, isTrue);

      playerService.setFullscreen(false);
      expect(playerService.state.isFullscreen, isFalse);
    });

    test('setFullscreen emits state via stateStream', () async {
      final states = <bool>[];
      final sub = playerService.stateStream.listen(
        (s) => states.add(s.isFullscreen),
      );

      playerService.setFullscreen(true);
      playerService.setFullscreen(false);
      playerService.setFullscreen(true);

      await Future.delayed(Duration.zero);
      await sub.cancel();

      expect(states, [true, false, true]);
    });

    test('stop() resets isFullscreen to default (false)', () async {
      when(() => mockPlayer.stop()).thenAnswer((_) async {});

      playerService.setFullscreen(true);
      expect(playerService.state.isFullscreen, isTrue);

      await playerService.stop();
      expect(playerService.state.isFullscreen, isFalse);
    });
  });

  group('PlayerService — cssObjectFitFromLabel', () {
    test('maps Fill to cover', () {
      expect(PlayerService.cssObjectFitFromLabel('Fill'), 'cover');
    });

    test('maps Fit to fill (stretch)', () {
      expect(PlayerService.cssObjectFitFromLabel('Fit'), 'fill');
    });

    test('maps Original to contain', () {
      expect(PlayerService.cssObjectFitFromLabel('Original'), 'contain');
    });

    test('maps 16:9 to contain', () {
      expect(PlayerService.cssObjectFitFromLabel('16:9'), 'contain');
    });

    test('maps 4:3 to contain', () {
      expect(PlayerService.cssObjectFitFromLabel('4:3'), 'contain');
    });

    test('maps unknown/Auto to contain (default)', () {
      expect(PlayerService.cssObjectFitFromLabel('Auto'), 'contain');
    });
  });

  group('PlayerService — aspectRatios constant', () {
    test('contains expected 5 labels in order', () {
      expect(PlayerService.aspectRatios, [
        'Original',
        '16:9',
        '4:3',
        'Fill',
        'Fit',
      ]);
    });
  });
}
