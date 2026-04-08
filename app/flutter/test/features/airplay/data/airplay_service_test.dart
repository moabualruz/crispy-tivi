import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/airplay/data/airplay_service.dart';

// ── Mocks ────────────────────────────────────────────

/// Mock AirPlayHelper that tracks calls and lets
/// tests control return values.
///
/// We can't import AirPlayHelper directly because
/// the conditional export picks io/stub at compile
/// time. Instead we test through the Notifier +
/// state, which is what production code uses.

void main() {
  // ── AirPlayState unit tests ──────────────────────

  group('AirPlayState', () {
    test('default state has no active device', () {
      const state = AirPlayState();

      expect(state.isSupported, isFalse);
      expect(state.isConnected, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.currentMedia, isNull);
    });

    test('copyWith preserves existing values', () {
      const original = AirPlayState(
        isSupported: true,
        isConnected: true,
        isPlaying: true,
        currentMedia: AirPlayMedia(
          url: 'http://stream.test/a.m3u8',
          title: 'Test',
        ),
      );

      final copy = original.copyWith();

      expect(copy.isSupported, isTrue);
      expect(copy.isConnected, isTrue);
      expect(copy.isPlaying, isTrue);
      expect(copy.currentMedia, isNotNull);
      expect(copy.currentMedia!.url, 'http://stream.test/a.m3u8');
    });

    test('copyWith replaces specific fields', () {
      const original = AirPlayState(
        isSupported: true,
        isConnected: true,
        isPlaying: true,
      );

      final copy = original.copyWith(isConnected: false, isPlaying: false);

      expect(copy.isSupported, isTrue);
      expect(copy.isConnected, isFalse);
      expect(copy.isPlaying, isFalse);
    });

    test('copyWith can set currentMedia to new value', () {
      const original = AirPlayState();
      final copy = original.copyWith(
        currentMedia: const AirPlayMedia(
          url: 'http://x.test/b.m3u8',
          title: 'Movie',
        ),
      );

      expect(copy.currentMedia, isNotNull);
      expect(copy.currentMedia!.title, 'Movie');
    });

    test('Equatable: equal states are ==', () {
      const a = AirPlayState(isSupported: true, isConnected: false);
      const b = AirPlayState(isSupported: true, isConnected: false);
      expect(a, equals(b));
    });

    test('Equatable: different states are !=', () {
      const a = AirPlayState(isConnected: true);
      const b = AirPlayState(isConnected: false);
      expect(a, isNot(equals(b)));
    });
  });

  // ── AirPlayMedia unit tests ──────────────────────

  group('AirPlayMedia', () {
    test('stores url and title', () {
      const media = AirPlayMedia(
        url: 'http://stream.test/live.ts',
        title: 'CNN',
      );

      expect(media.url, 'http://stream.test/live.ts');
      expect(media.title, 'CNN');
    });

    test('Equatable: same url+title are ==', () {
      const a = AirPlayMedia(url: 'u', title: 't');
      const b = AirPlayMedia(url: 'u', title: 't');
      expect(a, equals(b));
    });

    test('Equatable: different url are !=', () {
      const a = AirPlayMedia(url: 'u1', title: 't');
      const b = AirPlayMedia(url: 'u2', title: 't');
      expect(a, isNot(equals(b)));
    });

    test('Equatable: different title are !=', () {
      const a = AirPlayMedia(url: 'u', title: 't1');
      const b = AirPlayMedia(url: 'u', title: 't2');
      expect(a, isNot(equals(b)));
    });
  });

  // ── AirPlayService (Notifier) via container ──────

  group('AirPlayService', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state reports unsupported on '
        'non-Apple platform', () {
      final state = container.read(airplayServiceProvider);
      // On Windows/Linux test runner, AirPlay
      // uses the stub helper (unsupported).
      expect(state.isSupported, isFalse);
      expect(state.isConnected, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.currentMedia, isNull);
    });

    test('showPicker is callable without error on '
        'unsupported platform', () {
      // Stub helper's showPicker is a no-op.
      expect(
        () => container.read(airplayServiceProvider.notifier).showPicker(),
        returnsNormally,
      );
    });

    test('playUrl returns false on unsupported '
        'platform', () async {
      final result = await container
          .read(airplayServiceProvider.notifier)
          .playUrl('http://stream.test/a.m3u8', title: 'Test');

      expect(result, isFalse);
      // State unchanged because playback failed.
      final state = container.read(airplayServiceProvider);
      expect(state.isPlaying, isFalse);
      expect(state.currentMedia, isNull);
    });

    test('pause updates state to not playing', () {
      container.read(airplayServiceProvider.notifier).pause();

      final state = container.read(airplayServiceProvider);
      expect(state.isPlaying, isFalse);
    });

    test('resume updates state to playing', () {
      container.read(airplayServiceProvider.notifier).resume();

      final state = container.read(airplayServiceProvider);
      expect(state.isPlaying, isTrue);
    });

    test('stop clears media and stops playing', () {
      // First set some state via resume.
      container.read(airplayServiceProvider.notifier).resume();
      expect(container.read(airplayServiceProvider).isPlaying, isTrue);

      container.read(airplayServiceProvider.notifier).stop();

      final state = container.read(airplayServiceProvider);
      expect(state.isPlaying, isFalse);
      expect(state.currentMedia, isNull);
    });

    test('disconnect clears connection, media, '
        'and playing', () {
      container.read(airplayServiceProvider.notifier).resume();

      container.read(airplayServiceProvider.notifier).disconnect();

      final state = container.read(airplayServiceProvider);
      expect(state.isConnected, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.currentMedia, isNull);
    });

    test('isSupported getter delegates to helper', () {
      final notifier = container.read(airplayServiceProvider.notifier);
      // On Windows test runner, stub returns false.
      expect(notifier.isSupported, isFalse);
    });

    test('isConnected getter delegates to helper', () {
      final notifier = container.read(airplayServiceProvider.notifier);
      expect(notifier.isConnected, isFalse);
    });
  });
}
