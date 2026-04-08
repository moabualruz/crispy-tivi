import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

void main() {
  group('CacheService Provider', () {
    test(
      'BUG-005: cacheServiceProvider rebuilds when crispyBackendProvider changes',
      () {
        final backend1 = MemoryBackend();
        final backend2 = MemoryBackend();

        final container = ProviderContainer(
          overrides: [crispyBackendProvider.overrideWithValue(backend1)],
        );
        addTearDown(container.dispose);

        final cache1 = container.read(cacheServiceProvider);

        // Update the override to simulate backend reset (e.g. going offline to online)
        container.updateOverrides([
          crispyBackendProvider.overrideWithValue(backend2),
        ]);

        final cache2 = container.read(cacheServiceProvider);
        expect(
          cache1,
          isNot(same(cache2)),
          reason:
              'CacheService should be a new instance wrapping the new backend',
        );
      },
    );
  });
}
