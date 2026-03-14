import 'package:crispy_tivi/features/player/presentation/providers/rebuild_observer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A simple notifier whose value can be set to trigger updates.
class _CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state = state + 1;
}

final _counterProvider = NotifierProvider<_CounterNotifier, int>(
  _CounterNotifier.new,
  name: 'counter',
);

void main() {
  group('RebuildCountObserver', () {
    late RebuildCountObserver observer;

    setUp(() {
      observer = RebuildCountObserver();
    });

    test('countFor returns 0 for untracked provider', () {
      expect(observer.countFor('channelList'), 0);
      expect(observer.countFor('nonexistent'), 0);
    });

    test('tracks updates when notifier state changes', () {
      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      // Listen to activate the provider.
      container.listen(_counterProvider, (_, _) {});

      // Trigger N updates.
      const n = 5;
      for (var i = 0; i < n; i++) {
        container.read(_counterProvider.notifier).increment();
      }

      expect(observer.countFor('counter'), n);
    });

    test('reset clears all counts to 0', () {
      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      container.listen(_counterProvider, (_, _) {});
      container.read(_counterProvider.notifier).increment();
      container.read(_counterProvider.notifier).increment();

      expect(observer.countFor('counter'), 2);

      observer.reset();
      expect(observer.countFor('counter'), 0);
    });

    test('integration — rebuilds stay below threshold during flow', () {
      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      container.listen(_counterProvider, (_, _) {});

      // Simulate a user flow: several state changes.
      for (var i = 0; i < 3; i++) {
        container.read(_counterProvider.notifier).increment();
      }

      // Provider should rebuild exactly 3 times (well below 10).
      expect(observer.countFor('counter'), lessThanOrEqualTo(10));
      expect(observer.countFor('counter'), 3);
    });

    test('totalUpdates sums across multiple providers', () {
      final secondProvider = NotifierProvider<_CounterNotifier, int>(
        _CounterNotifier.new,
        name: 'second',
      );

      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      container.listen(_counterProvider, (_, _) {});
      container.listen(secondProvider, (_, _) {});

      container.read(_counterProvider.notifier).increment();
      container.read(secondProvider.notifier).increment();

      // One update each = 2 total.
      expect(observer.totalUpdates, 2);
    });

    test('uses runtimeType key when provider has no name', () {
      final unnamed = NotifierProvider<_CounterNotifier, int>(
        _CounterNotifier.new,
      );

      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      container.listen(unnamed, (_, _) {});
      container.read(unnamed.notifier).increment();

      // Should track under runtimeType, not crash.
      expect(observer.totalUpdates, 1);
    });
  });
}
