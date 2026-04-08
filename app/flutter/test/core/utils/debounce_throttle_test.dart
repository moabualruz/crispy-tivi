import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/utils/debounce_throttle.dart';

void main() {
  group('Debouncer', () {
    test('delays execution', () async {
      int count = 0;
      final debouncer = Debouncer(duration: const Duration(milliseconds: 50));

      debouncer.run(() => count++);
      debouncer.run(() => count++);
      debouncer.run(() => count++);

      expect(count, 0); // Not executed yet
      expect(debouncer.isPending, true);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(count, 1); // Executed only once
      expect(debouncer.isPending, false);
    });

    test('can be cancelled', () async {
      int count = 0;
      final debouncer = Debouncer(duration: const Duration(milliseconds: 50));

      debouncer.run(() => count++);
      debouncer.cancel();

      await Future.delayed(const Duration(milliseconds: 100));
      expect(count, 0);
      expect(debouncer.isPending, false);
    });
  });

  group('Throttler', () {
    test('limits execution frequency', () async {
      int count = 0;
      final throttler = Throttler(interval: const Duration(milliseconds: 100));

      // 1st call should execute
      expect(throttler.run(() => count++), true);

      // 2nd call right away should NOT execute
      expect(throttler.run(() => count++), false);
      expect(count, 1);

      // Wait for interval
      await Future.delayed(const Duration(milliseconds: 150));

      // 3rd call should execute
      expect(throttler.run(() => count++), true);
      expect(count, 2);
    });

    test('reset allows immediate execution', () {
      int count = 0;
      final throttler = Throttler(interval: const Duration(milliseconds: 1000));

      expect(throttler.run(() => count++), true);
      expect(throttler.run(() => count++), false);

      throttler.reset();
      expect(throttler.run(() => count++), true);
      expect(count, 2);
    });
  });
}
