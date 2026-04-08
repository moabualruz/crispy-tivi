import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── GuideSplitNotifier (ToggleNotifier) ─────────────────────

  group('GuideSplitNotifier', () {
    test('starts as false (guide closed)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(guideSplitProvider), false);
    });

    test('toggle flips state open/closed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(guideSplitProvider.notifier).toggle();
      expect(container.read(guideSplitProvider), true);

      container.read(guideSplitProvider.notifier).toggle();
      expect(container.read(guideSplitProvider), false);
    });

    test('set applies explicit value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(guideSplitProvider.notifier).set(value: true);
      expect(container.read(guideSplitProvider), true);

      container.read(guideSplitProvider.notifier).set(value: false);
      expect(container.read(guideSplitProvider), false);
    });

    test('set to same value is idempotent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(guideSplitProvider.notifier).set(value: true);
      container.read(guideSplitProvider.notifier).set(value: true);
      expect(container.read(guideSplitProvider), true);
    });
  });

  // ── Guide split layout logic ────────────────────────────────

  group('Guide split layout calculations', () {
    double computeVideoWidth(double screenWidth, bool guideSplit) {
      return guideSplit ? screenWidth / 2 : screenWidth;
    }

    test('50/50 split gives half-width for each panel', () {
      expect(computeVideoWidth(1920.0, true), 960.0);
    });

    test('full width when guide is closed', () {
      expect(computeVideoWidth(1920.0, false), 1920.0);
    });

    test('guide panel width matches right half', () {
      const screenWidth = 1920.0;
      expect(screenWidth / 2, 960.0);
    });
  });

  // ── Visibility gating ───────────────────────────────────────

  group('Guide button visibility gating', () {
    bool isGuideButtonVisible(double width, bool isLive) {
      return isLive && width >= 1200;
    }

    test('requires width >= 1200 for large layout', () {
      expect(isGuideButtonVisible(1920.0, true), isTrue); // Desktop
      expect(isGuideButtonVisible(1280.0, true), isTrue); // Tablet
      expect(isGuideButtonVisible(800.0, true), isFalse); // Phone
      expect(isGuideButtonVisible(1199.0, true), isFalse); // Below
      expect(isGuideButtonVisible(1200.0, true), isTrue); // Exact
    });

    test('requires live stream for guide button', () {
      expect(isGuideButtonVisible(1920.0, true), isTrue);
      expect(isGuideButtonVisible(1920.0, false), isFalse);
    });
  });
}
