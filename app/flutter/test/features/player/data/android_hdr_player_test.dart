import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/data/android_hdr_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AndroidHdrPlayer player;
  late List<MethodCall> methodCalls;

  setUp(() {
    methodCalls = [];

    // Mock the MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.crispytivi/hdr_player'),
          (call) async {
            methodCalls.add(call);
            switch (call.method) {
              case 'isHdrSupported':
                return true;
              case 'getSupportedHdrFormats':
                return ['hdr10', 'hlg'];
              default:
                return null;
            }
          },
        );

    player = AndroidHdrPlayer();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.crispytivi/hdr_player'),
          null,
        );
  });

  group('AndroidHdrPlayer', () {
    test('supportsHdr returns true', () {
      expect(player.supportsHdr, isTrue);
    });

    test('supportsPiP returns false', () {
      expect(player.supportsPiP, isFalse);
    });

    test('supportsBackgroundAudio returns false', () {
      expect(player.supportsBackgroundAudio, isFalse);
    });

    test('engineName returns media3', () {
      expect(player.engineName, 'media3');
    });

    test('currentUrl is null initially', () {
      expect(player.currentUrl, isNull);
    });

    test('open sends correct method call and tracks URL', () async {
      await player.open(
        'http://example.com/hdr.m3u8',
        httpHeaders: {'Authorization': 'Bearer token'},
        startPosition: const Duration(seconds: 30),
      );

      expect(player.currentUrl, 'http://example.com/hdr.m3u8');
      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, 'open');
      expect(methodCalls.first.arguments, {
        'url': 'http://example.com/hdr.m3u8',
        'headers': {'Authorization': 'Bearer token'},
        'startPositionMs': 30000,
      });
    });

    test('play sends play method call', () async {
      await player.play();
      expect(methodCalls.last.method, 'play');
    });

    test('pause sends pause method call', () async {
      await player.pause();
      expect(methodCalls.last.method, 'pause');
    });

    test('stop sends stop method call and clears URL', () async {
      await player.open('http://example.com/stream.m3u8');
      methodCalls.clear();

      await player.stop();
      expect(player.currentUrl, isNull);
      expect(methodCalls.last.method, 'stop');
    });

    test('seek sends correct position in milliseconds', () async {
      await player.seek(const Duration(minutes: 5, seconds: 30));
      expect(methodCalls.last.method, 'seek');
      expect(methodCalls.last.arguments, {'positionMs': 330000});
    });

    test('setVolume clamps and sends volume', () async {
      await player.setVolume(0.75);
      expect(player.volume, 0.75);
      expect(methodCalls.last.arguments, {'volume': 0.75});

      await player.setVolume(1.5);
      expect(player.volume, 1.0);
    });

    test('setRate sends rate', () async {
      await player.setRate(2.0);
      expect(player.rate, 2.0);
      expect(methodCalls.last.arguments, {'rate': 2.0});
    });

    test('setAudioTrack sends index', () async {
      await player.setAudioTrack(1);
      expect(methodCalls.last.arguments, {'index': 1});
    });

    test('setSubtitleTrack sends index', () async {
      await player.setSubtitleTrack(2);
      expect(methodCalls.last.arguments, {'index': 2});
    });

    test('isHdrSupported static method queries native plugin', () async {
      final supported = await AndroidHdrPlayer.isHdrSupported();
      expect(supported, isTrue);
    });

    test('getSupportedFormats static method queries native plugin', () async {
      final formats = await AndroidHdrPlayer.getSupportedFormats();
      expect(formats, ['hdr10', 'hlg']);
    });

    test('buildVideoWidget returns AndroidView', () {
      final widget = player.buildVideoWidget();
      expect(widget, isA<AndroidView>());
    });

    test('setProperty and getProperty are no-ops', () {
      player.setProperty('hwdec', 'auto');
      expect(player.getProperty('hwdec'), isNull);
    });

    test('initial state is zeroed', () {
      expect(player.position, Duration.zero);
      expect(player.duration, Duration.zero);
      expect(player.isPlaying, isFalse);
      expect(player.volume, 1.0);
      expect(player.rate, 1.0);
      expect(player.audioTracks, isEmpty);
      expect(player.subtitleTracks, isEmpty);
    });
  });
}
