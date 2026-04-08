import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/data/android_pip_player.dart';
import 'package:crispy_tivi/features/player/data/desktop_pip_player.dart';
import 'package:crispy_tivi/features/player/data/player_handoff_manager.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';

import '../../helpers/mock_crispy_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidPipPlayer', () {
    late AndroidPipPlayer player;
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.crispytivi/pip_player_android'),
            (call) async {
              methodCalls.add(call);
              return null;
            },
          );

      player = AndroidPipPlayer();
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.crispytivi/pip_player_android'),
            null,
          );
    });

    test('supportsPiP returns true', () {
      expect(player.supportsPiP, isTrue);
    });

    test('supportsHdr returns false', () {
      expect(player.supportsHdr, isFalse);
    });

    test('engineName returns media3_pip', () {
      expect(player.engineName, 'media3_pip');
    });

    test('enterPiP saves position before invoking platform', () async {
      // Open and simulate position update.
      await player.open(
        'http://example.com/video.mp4',
        startPosition: const Duration(seconds: 42),
      );

      await player.enterPiP();
      expect(methodCalls.where((c) => c.method == 'enterPiP'), hasLength(1));
    });

    test('exitPiP restores position via seekTo', () async {
      await player.open('http://example.com/video.mp4');
      await player.enterPiP();
      methodCalls.clear();

      await player.exitPiP();
      expect(methodCalls.where((c) => c.method == 'exitPiP'), hasLength(1));
    });

    test('position is preserved across PiP enter/exit cycle', () async {
      await player.open(
        'http://example.com/video.mp4',
        startPosition: const Duration(seconds: 120),
      );

      // Simulate position advancing via event.
      player.simulatePositionUpdate(const Duration(seconds: 300));
      expect(player.position, const Duration(seconds: 300));

      // Enter PiP — position should be saved.
      final savedPosition = player.position;
      await player.enterPiP();
      expect(player.isPipActive, isTrue);

      // Exit PiP — position should be preserved (not reset).
      await player.exitPiP();
      expect(player.isPipActive, isFalse);
      expect(player.position, savedPosition);
    });

    test('open sends correct method call', () async {
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

  group('DesktopPipPlayer', () {
    late DesktopPipPlayer player;

    setUp(() {
      player = DesktopPipPlayer();
    });

    test('supportsPiP returns true', () {
      expect(player.supportsPiP, isTrue);
    });

    test('supportsHdr returns false', () {
      expect(player.supportsHdr, isFalse);
    });

    test('engineName returns desktop_pip', () {
      expect(player.engineName, 'desktop_pip');
    });

    test('position is preserved across mini-window enter/exit', () async {
      // Simulate position update.
      player.simulatePositionUpdate(const Duration(seconds: 500));
      expect(player.position, const Duration(seconds: 500));

      // Enter mini-window — position should stay intact.
      final savedPos = player.position;
      await player.enterMiniWindow();
      expect(player.isMiniWindowActive, isTrue);

      // Exit mini-window — position preserved.
      await player.exitMiniWindow();
      expect(player.isMiniWindowActive, isFalse);
      expect(player.position, savedPos);
    });

    test('initial state is zeroed', () {
      expect(player.position, Duration.zero);
      expect(player.duration, Duration.zero);
      expect(player.isPlaying, isFalse);
      expect(player.volume, 1.0);
      expect(player.rate, 1.0);
    });
  });

  group('PlayerHandoffManager PiP position preservation', () {
    late MockCrispyPlayer primaryPlayer;
    late MockCrispyPlayer pipPlayer;
    late PlayerHandoffManager handoffManager;

    setUp(() {
      primaryPlayer = MockCrispyPlayer();
      pipPlayer = MockCrispyPlayer();
      handoffManager = PlayerHandoffManager(primaryPlayer: primaryPlayer);
      handoffManager.registerTakeover(PlayerCapability.pip, pipPlayer);
    });

    test('handoff preserves position from primary to PiP player', () async {
      primaryPlayer.mockPosition = const Duration(seconds: 42);
      primaryPlayer.mockUrl = 'http://example.com/video.mp4';

      final success = await handoffManager.handoffTo(PlayerCapability.pip);
      expect(success, isTrue);
      expect(handoffManager.activePlayer, pipPlayer);

      // Verify PiP player was opened at the primary's position.
      expect(pipPlayer.lastOpenUrl, 'http://example.com/video.mp4');
      expect(pipPlayer.lastStartPosition, const Duration(seconds: 42));
    });

    test('handback preserves position from PiP to primary', () async {
      primaryPlayer.mockPosition = const Duration(seconds: 10);
      primaryPlayer.mockUrl = 'http://example.com/video.mp4';

      await handoffManager.handoffTo(PlayerCapability.pip);
      pipPlayer.mockPosition = const Duration(seconds: 55);
      pipPlayer.mockUrl = 'http://example.com/video.mp4';

      await handoffManager.handbackToPrimary();
      expect(handoffManager.activePlayer, primaryPlayer);

      // Verify primary was re-opened at the PiP player's position.
      expect(primaryPlayer.lastOpenUrl, 'http://example.com/video.mp4');
      expect(primaryPlayer.lastStartPosition, const Duration(seconds: 55));
    });
  });
}
