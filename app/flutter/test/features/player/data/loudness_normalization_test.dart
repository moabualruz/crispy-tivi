import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/features/player/data/os_media_session.dart';
import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';

// Mocks
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

  group('Loudness Normalization', () {
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
      playerService = PlayerService(
        player: mockPlayer,
        mediaSession: _noOpMediaSession,
      );
    });

    tearDown(() {
      playerService.dispose();
    });

    test('loudness normalization defaults to enabled', () {
      expect(playerService.loudnessNormalization, isTrue);
    });

    test('stereo downmix defaults to disabled', () {
      expect(playerService.stereoDownmix, isFalse);
    });

    test('setLoudnessNormalization toggles the flag', () {
      playerService.setLoudnessNormalization(false);
      expect(playerService.loudnessNormalization, isFalse);

      playerService.setLoudnessNormalization(true);
      expect(playerService.loudnessNormalization, isTrue);
    });

    test('setStereoDownmix toggles the flag', () {
      playerService.setStereoDownmix(true);
      expect(playerService.stereoDownmix, isTrue);

      playerService.setStereoDownmix(false);
      expect(playerService.stereoDownmix, isFalse);
    });

    test('openMedia passes loudnorm filter when enabled', () async {
      playerService.setLoudnessNormalization(true);
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
      expect(extras!['af'], contains('loudnorm'));
    });

    test('openMedia omits loudnorm filter when disabled', () async {
      playerService.setLoudnessNormalization(false);
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
      // Either no extras or no 'af' key.
      if (extras != null && extras.containsKey('af')) {
        expect(extras['af'], isNot(contains('loudnorm')));
      }
    });

    test('openMedia passes stereo downmix when enabled', () async {
      playerService.setStereoDownmix(true);
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
      expect(extras!['audio-channels'], 'stereo');
      expect(extras['audio-normalize-downmix'], 'yes');
    });

    test('openMedia omits stereo downmix when disabled', () async {
      playerService.setStereoDownmix(false);
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
        expect(extras.containsKey('audio-channels'), isFalse);
      }
    });

    test('setAudioFilter composes with loudnorm when both active', () {
      playerService.setLoudnessNormalization(true);

      when(() => mockPlayer.setProperty(any(), any())).thenReturn(null);
      playerService.setAudioFilter('equalizer=1:2:3');

      verify(
        () => mockPlayer.setProperty(
          'af',
          'loudnorm=I=-14:TP=-1:LRA=13,equalizer=1:2:3',
        ),
      ).called(1);
    });

    test('setAudioFilter uses only eq when loudnorm disabled', () {
      playerService.setLoudnessNormalization(false);

      when(() => mockPlayer.setProperty(any(), any())).thenReturn(null);
      playerService.setAudioFilter('equalizer=1:2:3');

      verify(() => mockPlayer.setProperty('af', 'equalizer=1:2:3')).called(1);
    });

    test('setAudioFilter uses only loudnorm when eq is empty', () {
      playerService.setLoudnessNormalization(true);

      when(() => mockPlayer.setProperty(any(), any())).thenReturn(null);
      playerService.setAudioFilter('');

      verify(
        () => mockPlayer.setProperty('af', 'loudnorm=I=-14:TP=-1:LRA=13'),
      ).called(1);
    });

    test('setAudioFilter sets empty when both disabled', () {
      playerService.setLoudnessNormalization(false);

      when(() => mockPlayer.setProperty(any(), any())).thenReturn(null);
      playerService.setAudioFilter('');

      verify(() => mockPlayer.setProperty('af', '')).called(1);
    });
  });
}
