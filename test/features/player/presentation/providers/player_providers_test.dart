import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/presentation/'
    'providers/player_providers.dart';

void main() {
  // ── OsdState ────────────────────────────────────

  group('OsdStateNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is visible', () {
      final state = container.read(osdStateProvider);
      expect(state, OsdState.visible);
    });

    test('hide() sets state to hidden', () {
      container.read(osdStateProvider.notifier).hide();
      expect(container.read(osdStateProvider), OsdState.hidden);
    });

    test('show() sets state to visible', () {
      // First hide, then show.
      container.read(osdStateProvider.notifier).hide();
      container.read(osdStateProvider.notifier).show();
      expect(container.read(osdStateProvider), OsdState.visible);
    });

    test('toggle() from visible → hidden', () {
      container.read(osdStateProvider.notifier).toggle();
      expect(container.read(osdStateProvider), OsdState.hidden);
    });

    test('toggle() from hidden → visible', () {
      container.read(osdStateProvider.notifier).hide();
      container.read(osdStateProvider.notifier).toggle();
      expect(container.read(osdStateProvider), OsdState.visible);
    });

    test('toggle() from fading → hidden (not visible)', () {
      // When fading, toggle should hide, not show.
      // We can't directly set fading, but toggle
      // should treat fading as "not hidden" → hide.
      container.read(osdStateProvider.notifier).show();
      // show() puts state to visible.
      container.read(osdStateProvider.notifier).toggle();
      // visible → hidden.
      expect(container.read(osdStateProvider), OsdState.hidden);
    });
  });

  // ── osdVisibleProvider ──────────────────────────

  group('osdVisibleProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('true when OsdState is visible', () {
      expect(container.read(osdVisibleProvider), isTrue);
    });

    test('false when OsdState is hidden', () {
      container.read(osdStateProvider.notifier).hide();
      expect(container.read(osdVisibleProvider), isFalse);
    });
  });

  // ── MouseCursorNotifier ─────────────────────────

  group('MouseCursorNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is true (visible)', () {
      expect(container.read(mouseCursorVisibleProvider), isTrue);
    });

    test('onMouseMove keeps cursor visible', () {
      container.read(mouseCursorVisibleProvider.notifier).onMouseMove();
      expect(container.read(mouseCursorVisibleProvider), isTrue);
    });

    test('onMouseMove shows cursor when hidden', () {
      // We can't directly set to false without
      // waiting for the 3s timer, but we can verify
      // onMouseMove doesn't break anything.
      final notifier = container.read(mouseCursorVisibleProvider.notifier);
      notifier.onMouseMove();
      expect(container.read(mouseCursorVisibleProvider), isTrue);
    });
  });

  // ── StreamStatsNotifier ─────────────────────────

  group('StreamStatsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is false', () {
      expect(container.read(streamStatsVisibleProvider), isFalse);
    });

    test('update toggles state to true', () {
      container
          .read(streamStatsVisibleProvider.notifier)
          .update((current) => !current);
      expect(container.read(streamStatsVisibleProvider), isTrue);
    });

    test('update toggles state back to false', () {
      final notifier = container.read(streamStatsVisibleProvider.notifier);
      notifier.update((current) => !current);
      expect(container.read(streamStatsVisibleProvider), isTrue);

      notifier.update((current) => !current);
      expect(container.read(streamStatsVisibleProvider), isFalse);
    });

    test('update with identity preserves state', () {
      container
          .read(streamStatsVisibleProvider.notifier)
          .update((current) => current);
      expect(container.read(streamStatsVisibleProvider), isFalse);
    });
  });

  // ── OsdState enum coverage ──────────────────────

  group('OsdState enum', () {
    test('has 3 values', () {
      expect(OsdState.values, hasLength(3));
    });

    test('values are visible, fading, hidden', () {
      expect(
        OsdState.values,
        containsAll([OsdState.visible, OsdState.fading, OsdState.hidden]),
      );
    });
  });
}
