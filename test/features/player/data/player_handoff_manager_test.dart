import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/features/player/data/player_handoff_manager.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';

class MockCrispyPlayer extends Mock implements CrispyPlayer {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(BoxFit.contain);
  });

  late MockCrispyPlayer primaryPlayer;
  late PlayerHandoffManager manager;

  setUp(() {
    primaryPlayer = MockCrispyPlayer();
    manager = PlayerHandoffManager(primaryPlayer: primaryPlayer);
  });

  group('PlayerHandoffManager', () {
    test('activePlayer is primary by default', () {
      expect(manager.activePlayer, same(primaryPlayer));
    });

    test('handoffTo returns false for unregistered capability', () async {
      final result = await manager.handoffTo('hdr');
      expect(result, isFalse);
      expect(manager.activePlayer, same(primaryPlayer));
    });

    test('handoffTo returns false when no URL loaded', () async {
      final target = MockCrispyPlayer();
      manager.registerTakeover('hdr', target);

      when(() => primaryPlayer.currentUrl).thenReturn(null);
      when(() => primaryPlayer.position).thenReturn(Duration.zero);

      final result = await manager.handoffTo('hdr');
      expect(result, isFalse);
    });

    test(
      'handoffTo pauses source and opens target at saved position',
      () async {
        final target = MockCrispyPlayer();
        manager.registerTakeover('hdr', target);

        when(
          () => primaryPlayer.currentUrl,
        ).thenReturn('http://example.com/hdr.m3u8');
        when(
          () => primaryPlayer.position,
        ).thenReturn(const Duration(minutes: 5));
        when(() => primaryPlayer.pause()).thenAnswer((_) async {});
        when(
          () => target.open(
            any(),
            startPosition: any(named: 'startPosition'),
            httpHeaders: any(named: 'httpHeaders'),
            extras: any(named: 'extras'),
          ),
        ).thenAnswer((_) async {});

        final result = await manager.handoffTo('hdr');

        expect(result, isTrue);
        expect(manager.activePlayer, same(target));
        verify(() => primaryPlayer.pause()).called(1);
        verify(
          () => target.open(
            'http://example.com/hdr.m3u8',
            startPosition: const Duration(minutes: 5),
          ),
        ).called(1);
      },
    );

    test('handbackToPrimary is no-op when already on primary', () async {
      await manager.handbackToPrimary();
      // No interactions with primaryPlayer besides construction.
      verifyNever(() => primaryPlayer.stop());
      verifyNever(
        () => primaryPlayer.open(
          any(),
          startPosition: any(named: 'startPosition'),
          httpHeaders: any(named: 'httpHeaders'),
          extras: any(named: 'extras'),
        ),
      );
    });

    test('handbackToPrimary stops target and opens primary', () async {
      final target = MockCrispyPlayer();
      manager.registerTakeover('hdr', target);

      // Perform handoff first.
      when(
        () => primaryPlayer.currentUrl,
      ).thenReturn('http://example.com/hdr.m3u8');
      when(() => primaryPlayer.position).thenReturn(const Duration(minutes: 5));
      when(() => primaryPlayer.pause()).thenAnswer((_) async {});
      when(
        () => target.open(
          any(),
          startPosition: any(named: 'startPosition'),
          httpHeaders: any(named: 'httpHeaders'),
          extras: any(named: 'extras'),
        ),
      ).thenAnswer((_) async {});
      await manager.handoffTo('hdr');

      // Now hand back.
      when(() => target.currentUrl).thenReturn('http://example.com/hdr.m3u8');
      when(
        () => target.position,
      ).thenReturn(const Duration(minutes: 7, seconds: 30));
      when(() => target.stop()).thenAnswer((_) async {});
      when(
        () => primaryPlayer.open(
          any(),
          startPosition: any(named: 'startPosition'),
          httpHeaders: any(named: 'httpHeaders'),
          extras: any(named: 'extras'),
        ),
      ).thenAnswer((_) async {});

      await manager.handbackToPrimary();

      expect(manager.activePlayer, same(primaryPlayer));
      verify(() => target.stop()).called(1);
      verify(
        () => primaryPlayer.open(
          'http://example.com/hdr.m3u8',
          startPosition: const Duration(minutes: 7, seconds: 30),
        ),
      ).called(1);
    });

    test('disposeAll disposes all registered takeover players', () async {
      final hdrPlayer = MockCrispyPlayer();
      final pipPlayer = MockCrispyPlayer();
      manager.registerTakeover('hdr', hdrPlayer);
      manager.registerTakeover('pip', pipPlayer);

      when(() => hdrPlayer.dispose()).thenAnswer((_) async {});
      when(() => pipPlayer.dispose()).thenAnswer((_) async {});

      await manager.disposeAll();

      verify(() => hdrPlayer.dispose()).called(1);
      verify(() => pipPlayer.dispose()).called(1);

      // After disposal, handoff should fail.
      final result = await manager.handoffTo('hdr');
      expect(result, isFalse);
    });
  });
}
