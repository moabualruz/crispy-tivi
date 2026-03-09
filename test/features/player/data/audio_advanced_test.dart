import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/features/player/data/media_kit_player.dart';
import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';

// ── Mocks ────────────────────────────────────────────────

class MockCrispyPlayer extends Mock implements CrispyPlayer {}

class MockPlayer extends Mock implements Player {}

class MockPlayerStream extends Mock implements PlayerStream {}

class MockPlayerState extends Mock implements PlayerState {}

class MockTracks extends Mock implements Tracks {}

void _stubEmptyStreams(MockCrispyPlayer mock) {
  when(() => mock.playingStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.positionStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.durationStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.bufferStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.bufferingStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.completedStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.volumeStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.rateStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.errorStream).thenAnswer((_) => const Stream.empty());
  when(() => mock.tracksStream).thenAnswer((_) => const Stream.empty());

  when(() => mock.pause()).thenAnswer((_) async {});
  when(() => mock.dispose()).thenAnswer((_) async {});
  when(() => mock.setVolume(any())).thenAnswer((_) async {});
  when(() => mock.setProperty(any(), any())).thenReturn(null);
}

void _stubMediaKitDefaults(
  MockPlayer mockPlayer,
  MockPlayerStream mockStreams,
  MockPlayerState mockState,
  MockTracks mockTracks,
) {
  when(() => mockPlayer.stream).thenReturn(mockStreams);
  when(() => mockPlayer.state).thenReturn(mockState);
  when(() => mockState.tracks).thenReturn(mockTracks);
  when(() => mockTracks.audio).thenReturn([]);
  when(() => mockTracks.subtitle).thenReturn([]);

  when(() => mockStreams.position).thenAnswer((_) => const Stream.empty());
  when(() => mockStreams.duration).thenAnswer((_) => const Stream.empty());
  when(() => mockStreams.buffer).thenAnswer((_) => const Stream.empty());
  when(() => mockStreams.playing).thenAnswer((_) => const Stream.empty());
  when(() => mockStreams.completed).thenAnswer((_) => const Stream.empty());
  when(() => mockStreams.error).thenAnswer((_) => const Stream.empty());
  when(() => mockStreams.buffering).thenAnswer((_) => const Stream.empty());
  when(() => mockStreams.volume).thenAnswer((_) => const Stream.empty());
  when(() => mockStreams.rate).thenAnswer((_) => const Stream.empty());
  when(() => mockStreams.tracks).thenAnswer((_) => const Stream.empty());

  when(() => mockState.position).thenReturn(Duration.zero);
  when(() => mockState.duration).thenReturn(Duration.zero);
  when(() => mockState.playing).thenReturn(false);
  when(() => mockState.volume).thenReturn(100.0);
  when(() => mockState.rate).thenReturn(1.0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(Media(''));
    registerFallbackValue(const AudioTrack('', '', null));
    registerFallbackValue(const AudioDevice('', ''));
  });

  // ── Audio Passthrough ───────────────────────────────────

  group('Audio Passthrough', () {
    late MockCrispyPlayer mockPlayer;
    late PlayerService playerService;

    setUp(() {
      mockPlayer = MockCrispyPlayer();
      _stubEmptyStreams(mockPlayer);
      when(
        () => mockPlayer.open(
          any(),
          httpHeaders: any(named: 'httpHeaders'),
          extras: any(named: 'extras'),
        ),
      ).thenAnswer((_) async {});
      playerService = PlayerService(player: mockPlayer);
    });

    tearDown(() {
      playerService.dispose();
    });

    test('passthrough defaults to disabled', () {
      expect(playerService.audioPassthroughEnabled, isFalse);
    });

    test('setAudioPassthrough toggles the flag', () {
      playerService.setAudioPassthrough(true, ['ac3', 'dts']);
      expect(playerService.audioPassthroughEnabled, isTrue);
      expect(playerService.audioPassthroughCodecs, ['ac3', 'dts']);

      playerService.setAudioPassthrough(false, []);
      expect(playerService.audioPassthroughEnabled, isFalse);
    });

    test('openMedia passes audio-spdif when passthrough enabled', () async {
      playerService.setAudioPassthrough(true, ['ac3', 'dts', 'eac3']);
      await playerService.openMedia('http://example.com/stream.m3u8');

      final captured =
          verify(
            () => mockPlayer.open(
              any(),
              httpHeaders: any(named: 'httpHeaders'),
              extras: captureAny(named: 'extras'),
            ),
          ).captured;

      final extras = captured.last as Map<String, dynamic>?;
      expect(extras, isNotNull);
      expect(extras!['audio-spdif'], 'ac3,dts,eac3');
    });

    test('openMedia omits audio-spdif when passthrough disabled', () async {
      playerService.setAudioPassthrough(false, ['ac3', 'dts']);
      await playerService.openMedia('http://example.com/stream.m3u8');

      final captured =
          verify(
            () => mockPlayer.open(
              any(),
              httpHeaders: any(named: 'httpHeaders'),
              extras: captureAny(named: 'extras'),
            ),
          ).captured;

      final extras = captured.last as Map<String, dynamic>?;
      if (extras != null) {
        expect(extras.containsKey('audio-spdif'), isFalse);
      }
    });
  });

  // ── Audio Device (MediaKitPlayer) ─────────────────────

  group('MediaKitPlayer Audio Device', () {
    late MockPlayer mockPlayer;
    late MockPlayerStream mockStreams;
    late MockPlayerState mockState;
    late MockTracks mockTracks;

    setUp(() {
      mockPlayer = MockPlayer();
      mockStreams = MockPlayerStream();
      mockState = MockPlayerState();
      mockTracks = MockTracks();
      _stubMediaKitDefaults(mockPlayer, mockStreams, mockState, mockTracks);
    });

    test('audioDevices maps from media_kit AudioDevice list', () {
      when(() => mockState.audioDevices).thenReturn([
        const AudioDevice('auto', 'Autoselect device'),
        const AudioDevice('wasapi/{abc-123}', 'Speakers (Realtek)'),
      ]);

      final player = MediaKitPlayer(player: mockPlayer);
      final devices = player.audioDevices;

      expect(devices, hasLength(2));
      expect(devices[0].name, 'auto');
      expect(devices[0].description, 'Autoselect device');
      expect(devices[1].name, 'wasapi/{abc-123}');
      expect(devices[1].description, 'Speakers (Realtek)');
    });

    test('audioDevices returns empty list on error', () {
      when(() => mockState.audioDevices).thenThrow(Exception('no devices'));

      final player = MediaKitPlayer(player: mockPlayer);
      expect(player.audioDevices, isEmpty);
    });

    test('currentAudioDeviceName returns current device name', () {
      when(
        () => mockState.audioDevice,
      ).thenReturn(const AudioDevice('wasapi/{abc-123}', 'Speakers'));

      final player = MediaKitPlayer(player: mockPlayer);
      expect(player.currentAudioDeviceName, 'wasapi/{abc-123}');
    });

    test('setAudioDevice selects matching device', () {
      when(() => mockState.audioDevices).thenReturn([
        const AudioDevice('auto', 'Autoselect'),
        const AudioDevice('wasapi/{abc}', 'Speakers'),
      ]);
      when(() => mockPlayer.setAudioDevice(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      player.setAudioDevice('wasapi/{abc}');

      final captured =
          verify(() => mockPlayer.setAudioDevice(captureAny())).captured.single
              as AudioDevice;
      expect(captured.name, 'wasapi/{abc}');
    });

    test('setAudioDevice does nothing when name not found', () {
      when(
        () => mockState.audioDevices,
      ).thenReturn([const AudioDevice('auto', 'Autoselect')]);

      final player = MediaKitPlayer(player: mockPlayer);
      player.setAudioDevice('nonexistent');

      verifyNever(() => mockPlayer.setAudioDevice(any()));
    });
  });

  // ── Volume Boost (PlayerService) ──────────────────────

  group('Volume Boost', () {
    late MockCrispyPlayer mockPlayer;
    late PlayerService playerService;

    setUp(() {
      mockPlayer = MockCrispyPlayer();
      _stubEmptyStreams(mockPlayer);
      when(
        () => mockPlayer.open(
          any(),
          httpHeaders: any(named: 'httpHeaders'),
          extras: any(named: 'extras'),
        ),
      ).thenAnswer((_) async {});
      playerService = PlayerService(player: mockPlayer);
    });

    tearDown(() {
      playerService.dispose();
    });

    test('maxVolume defaults to 100', () {
      expect(playerService.maxVolume, 100);
    });

    test('setMaxVolume updates the value', () {
      playerService.setMaxVolume(200);
      expect(playerService.maxVolume, 200);
    });

    test('setMaxVolume clamps to 100-300 range', () {
      playerService.setMaxVolume(50);
      expect(playerService.maxVolume, 100);

      playerService.setMaxVolume(500);
      expect(playerService.maxVolume, 300);
    });

    test('setMaxVolume sets volume-max mpv property', () {
      playerService.setMaxVolume(200);

      verify(() => mockPlayer.setProperty('volume-max', '200')).called(1);
    });

    test('setVolume clamps to maxVolume/100', () async {
      playerService.setMaxVolume(200);
      await playerService.setVolume(2.5);

      // Should be clamped to 2.0 (200/100)
      verify(() => mockPlayer.setVolume(2.0)).called(1);
    });

    test('setVolume allows boost within maxVolume', () async {
      playerService.setMaxVolume(200);
      await playerService.setVolume(1.5);

      verify(() => mockPlayer.setVolume(1.5)).called(1);
    });

    test('openMedia passes volume-max when maxVolume > 100', () async {
      playerService.setMaxVolume(200);
      await playerService.openMedia('http://example.com/stream.m3u8');

      final captured =
          verify(
            () => mockPlayer.open(
              any(),
              httpHeaders: any(named: 'httpHeaders'),
              extras: captureAny(named: 'extras'),
            ),
          ).captured;

      final extras = captured.last as Map<String, dynamic>?;
      expect(extras, isNotNull);
      expect(extras!['volume-max'], '200');
    });

    test('openMedia omits volume-max when maxVolume is 100', () async {
      await playerService.openMedia('http://example.com/stream.m3u8');

      final captured =
          verify(
            () => mockPlayer.open(
              any(),
              httpHeaders: any(named: 'httpHeaders'),
              extras: captureAny(named: 'extras'),
            ),
          ).captured;

      final extras = captured.last as Map<String, dynamic>?;
      if (extras != null) {
        expect(extras.containsKey('volume-max'), isFalse);
      }
    });
  });

  // ── MediaKitPlayer Volume Boost ───────────────────────

  group('MediaKitPlayer Volume Boost', () {
    late MockPlayer mockPlayer;
    late MockPlayerStream mockStreams;
    late MockPlayerState mockState;
    late MockTracks mockTracks;

    setUp(() {
      mockPlayer = MockPlayer();
      mockStreams = MockPlayerStream();
      mockState = MockPlayerState();
      mockTracks = MockTracks();
      _stubMediaKitDefaults(mockPlayer, mockStreams, mockState, mockTracks);
    });

    test('setVolume passes boost values to mpv (1.5 → 150)', () async {
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.setVolume(1.5);

      verify(() => mockPlayer.setVolume(150.0)).called(1);
    });

    test('setVolume passes max boost (3.0 → 300)', () async {
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.setVolume(3.0);

      verify(() => mockPlayer.setVolume(300.0)).called(1);
    });

    test('setVolume clamps negative to 0', () async {
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.setVolume(-0.5);

      verify(() => mockPlayer.setVolume(0.0)).called(1);
    });
  });

  // ── CrispyAudioDevice ─────────────────────────────────

  group('CrispyAudioDevice', () {
    test('stores name and description', () {
      const device = CrispyAudioDevice(
        name: 'wasapi/{abc}',
        description: 'Speakers (Realtek HD)',
      );
      expect(device.name, 'wasapi/{abc}');
      expect(device.description, 'Speakers (Realtek HD)');
    });
  });
}
