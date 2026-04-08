import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/data/ios_pip_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IosPipPlayer player;
  late List<MethodCall> methodCalls;

  setUp(() {
    methodCalls = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.crispytivi/pip_player'),
          (call) async {
            methodCalls.add(call);
            return null;
          },
        );

    player = IosPipPlayer();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.crispytivi/pip_player'),
          null,
        );
  });

  group('IosPipPlayer', () {
    test('supportsHdr returns false', () {
      expect(player.supportsHdr, isFalse);
    });

    test('supportsPiP returns true', () {
      expect(player.supportsPiP, isTrue);
    });

    test('supportsBackgroundAudio returns true', () {
      expect(player.supportsBackgroundAudio, isTrue);
    });

    test('engineName returns avplayer', () {
      expect(player.engineName, 'avplayer');
    });

    test('currentUrl is null initially', () {
      expect(player.currentUrl, isNull);
    });

    test('isPipActive is false initially', () {
      expect(player.isPipActive, isFalse);
    });

    test('open sends correct method call and tracks URL', () async {
      await player.open(
        'http://example.com/stream.m3u8',
        httpHeaders: {'Authorization': 'Bearer tok'},
        startPosition: const Duration(seconds: 10),
      );

      expect(player.currentUrl, 'http://example.com/stream.m3u8');
      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, 'open');
      expect(methodCalls.first.arguments, {
        'url': 'http://example.com/stream.m3u8',
        'headers': {'Authorization': 'Bearer tok'},
        'startPositionMs': 10000,
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

    test('seek sends correct position', () async {
      await player.seek(const Duration(minutes: 2, seconds: 15));
      expect(methodCalls.last.method, 'seek');
      expect(methodCalls.last.arguments, {'positionMs': 135000});
    });

    test('setVolume clamps and sends volume', () async {
      await player.setVolume(0.5);
      expect(player.volume, 0.5);
      expect(methodCalls.last.arguments, {'volume': 0.5});

      await player.setVolume(2.0);
      expect(player.volume, 1.0);
    });

    test('setRate sends rate', () async {
      await player.setRate(1.5);
      expect(player.rate, 1.5);
      expect(methodCalls.last.arguments, {'rate': 1.5});
    });

    test('enterPiP sends enterPiP method call', () async {
      await player.enterPiP();
      expect(methodCalls.last.method, 'enterPiP');
    });

    test('exitPiP sends exitPiP method call', () async {
      await player.exitPiP();
      expect(methodCalls.last.method, 'exitPiP');
    });

    test('buildVideoWidget returns UiKitView', () {
      final widget = player.buildVideoWidget();
      expect(widget, isA<UiKitView>());
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
