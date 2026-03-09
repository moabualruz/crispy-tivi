import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/features/player/data/media_kit_player.dart';

class MockPlayer extends Mock implements Player {}

class MockPlayerStream extends Mock implements PlayerStream {}

class MockPlayerState extends Mock implements PlayerState {}

class MockTracks extends Mock implements Tracks {}

void main() {
  setUpAll(() {
    registerFallbackValue(Media(''));
    registerFallbackValue(const AudioTrack('', '', null));
    registerFallbackValue(const SubtitleTrack('', '', null));
    registerFallbackValue(Duration.zero);
  });

  late MockPlayer mockPlayer;
  late MockPlayerStream mockStreams;
  late MockPlayerState mockState;
  late MockTracks mockTracks;

  setUp(() {
    mockPlayer = MockPlayer();
    mockStreams = MockPlayerStream();
    mockState = MockPlayerState();
    mockTracks = MockTracks();

    when(() => mockPlayer.stream).thenReturn(mockStreams);
    when(() => mockPlayer.state).thenReturn(mockState);
    when(() => mockState.tracks).thenReturn(mockTracks);
    when(() => mockTracks.audio).thenReturn([]);
    when(() => mockTracks.subtitle).thenReturn([]);

    // Default stream stubs.
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

    // Default state stubs.
    when(() => mockState.position).thenReturn(Duration.zero);
    when(() => mockState.duration).thenReturn(Duration.zero);
    when(() => mockState.playing).thenReturn(false);
    when(() => mockState.volume).thenReturn(100.0);
    when(() => mockState.rate).thenReturn(1.0);
  });

  group('MediaKitPlayer', () {
    test('open calls Player.open with correct Media', () async {
      when(() => mockPlayer.open(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.open(
        'http://example.com/stream.m3u8',
        httpHeaders: {'Authorization': 'Bearer token'},
      );

      final captured =
          verify(() => mockPlayer.open(captureAny())).captured.single as Media;
      expect(captured.uri, 'http://example.com/stream.m3u8');
      expect(captured.httpHeaders, {'Authorization': 'Bearer token'});
    });

    test('open with startPosition seeks after opening', () async {
      when(() => mockPlayer.open(any())).thenAnswer((_) async {});
      when(() => mockPlayer.seek(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.open(
        'http://example.com/video.mp4',
        startPosition: const Duration(seconds: 30),
      );

      verify(() => mockPlayer.open(any())).called(1);
      verify(() => mockPlayer.seek(const Duration(seconds: 30))).called(1);
    });

    test('setVolume normalizes 0.0-1.0 to 0-100', () async {
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.setVolume(0.5);

      verify(() => mockPlayer.setVolume(50.0)).called(1);
    });

    test('setVolume allows boost beyond 1.0', () async {
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.setVolume(1.5);

      verify(() => mockPlayer.setVolume(150.0)).called(1);
    });

    test('volumeStream normalizes 0-100 to 0.0-1.0', () async {
      final ctrl = StreamController<double>.broadcast();
      when(() => mockStreams.volume).thenAnswer((_) => ctrl.stream);

      final player = MediaKitPlayer(player: mockPlayer);
      final values = <double>[];
      player.volumeStream.listen(values.add);

      ctrl.add(50.0);
      ctrl.add(100.0);
      ctrl.add(0.0);
      await Future.delayed(Duration.zero);

      expect(values, [0.5, 1.0, 0.0]);
      await ctrl.close();
    });

    test('errorStream maps empty string to null', () async {
      final ctrl = StreamController<String>.broadcast();
      when(() => mockStreams.error).thenAnswer((_) => ctrl.stream);

      final player = MediaKitPlayer(player: mockPlayer);
      final values = <String?>[];
      player.errorStream.listen(values.add);

      ctrl.add('');
      ctrl.add('Connection failed');
      ctrl.add('');
      await Future.delayed(Duration.zero);

      expect(values, [null, 'Connection failed', null]);
      await ctrl.close();
    });

    test('volume getter normalizes state value', () {
      when(() => mockState.volume).thenReturn(75.0);

      final player = MediaKitPlayer(player: mockPlayer);
      expect(player.volume, 0.75);
    });

    test('setAudioTrack filters sentinel tracks', () async {
      when(() => mockTracks.audio).thenReturn([
        const AudioTrack('auto', null, null),
        const AudioTrack('no', null, null),
        const AudioTrack('1', 'English', 'en'),
        const AudioTrack('2', 'Spanish', 'es'),
      ]);
      when(() => mockPlayer.setAudioTrack(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.setAudioTrack(1);

      final captured =
          verify(() => mockPlayer.setAudioTrack(captureAny())).captured.single
              as AudioTrack;
      expect(captured.id, '2');
      expect(captured.title, 'Spanish');
    });

    test('setSubtitleTrack(-1) disables subtitles', () async {
      when(() => mockPlayer.setSubtitleTrack(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.setSubtitleTrack(-1);

      final captured =
          verify(
                () => mockPlayer.setSubtitleTrack(captureAny()),
              ).captured.single
              as SubtitleTrack;
      expect(captured.id, 'no');
    });

    test('audioTracks maps correctly with filtered sentinels', () {
      when(() => mockTracks.audio).thenReturn([
        const AudioTrack('auto', null, null),
        const AudioTrack('1', 'English', 'en'),
        const AudioTrack('no', null, null),
        const AudioTrack('2', null, 'fr'),
      ]);

      final player = MediaKitPlayer(player: mockPlayer);
      final tracks = player.audioTracks;

      expect(tracks, hasLength(2));
      expect(tracks[0].index, 0);
      expect(tracks[0].title, 'English');
      expect(tracks[0].language, 'en');
      expect(tracks[1].index, 1);
      expect(tracks[1].title, 'fr'); // Falls back to language
      expect(tracks[1].language, 'fr');
    });

    test('supportsHdr returns false', () {
      final player = MediaKitPlayer(player: mockPlayer);
      expect(player.supportsHdr, isFalse);
    });

    test('supportsPiP returns false', () {
      final player = MediaKitPlayer(player: mockPlayer);
      expect(player.supportsPiP, isFalse);
    });

    test('supportsBackgroundAudio returns true', () {
      final player = MediaKitPlayer(player: mockPlayer);
      expect(player.supportsBackgroundAudio, isTrue);
    });

    test('engineName is media_kit', () {
      final player = MediaKitPlayer(player: mockPlayer);
      expect(player.engineName, 'media_kit');
    });

    test('currentUrl tracks open/stop lifecycle', () async {
      when(() => mockPlayer.open(any())).thenAnswer((_) async {});
      when(() => mockPlayer.stop()).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      expect(player.currentUrl, isNull);

      await player.open('http://example.com/live.m3u8');
      expect(player.currentUrl, 'http://example.com/live.m3u8');

      await player.stop();
      expect(player.currentUrl, isNull);
    });

    test('dispose clears currentUrl', () async {
      when(() => mockPlayer.open(any())).thenAnswer((_) async {});
      when(() => mockPlayer.pause()).thenAnswer((_) async {});
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.open('http://example.com/video.mp4');
      expect(player.currentUrl, isNotNull);

      await player.dispose();
      expect(player.currentUrl, isNull);
    });

    test('play delegates to Player.play', () async {
      when(() => mockPlayer.play()).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.play();

      verify(() => mockPlayer.play()).called(1);
    });

    test('pause delegates to Player.pause', () async {
      when(() => mockPlayer.pause()).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.pause();

      verify(() => mockPlayer.pause()).called(1);
    });

    test('seek delegates to Player.seek', () async {
      when(() => mockPlayer.seek(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.seek(const Duration(minutes: 5));

      verify(() => mockPlayer.seek(const Duration(minutes: 5))).called(1);
    });

    test('setRate delegates to Player.setRate', () async {
      when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});

      final player = MediaKitPlayer(player: mockPlayer);
      await player.setRate(2.0);

      verify(() => mockPlayer.setRate(2.0)).called(1);
    });

    test('positionStream delegates directly', () async {
      final ctrl = StreamController<Duration>.broadcast();
      when(() => mockStreams.position).thenAnswer((_) => ctrl.stream);

      final player = MediaKitPlayer(player: mockPlayer);
      final values = <Duration>[];
      player.positionStream.listen(values.add);

      ctrl.add(const Duration(seconds: 10));
      ctrl.add(const Duration(seconds: 20));
      await Future.delayed(Duration.zero);

      expect(values, [
        const Duration(seconds: 10),
        const Duration(seconds: 20),
      ]);
      await ctrl.close();
    });
  });
}
