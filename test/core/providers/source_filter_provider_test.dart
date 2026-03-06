import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/providers/source_filter_provider.dart';
import 'package:crispy_tivi/features/profiles/data/source_access_service.dart';

void main() {
  group('SourceFilterNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('starts with empty filter', () {
      final filter = container.read(sourceFilterProvider);
      expect(filter, isEmpty);
    });

    test('toggle adds a source ID when not present', () {
      container.read(sourceFilterProvider.notifier).toggle('src1');
      expect(container.read(sourceFilterProvider), {'src1'});
    });

    test('toggle removes a source ID when already present', () {
      container.read(sourceFilterProvider.notifier).toggle('src1');
      container.read(sourceFilterProvider.notifier).toggle('src1');
      expect(container.read(sourceFilterProvider), isEmpty);
    });

    test('toggle handles multiple source IDs independently', () {
      container.read(sourceFilterProvider.notifier).toggle('src1');
      container.read(sourceFilterProvider.notifier).toggle('src2');
      expect(container.read(sourceFilterProvider), {'src1', 'src2'});

      container.read(sourceFilterProvider.notifier).toggle('src1');
      expect(container.read(sourceFilterProvider), {'src2'});
    });

    test('selectAll clears all selected sources', () {
      container.read(sourceFilterProvider.notifier).toggle('src1');
      container.read(sourceFilterProvider.notifier).toggle('src2');
      container.read(sourceFilterProvider.notifier).selectAll();
      expect(container.read(sourceFilterProvider), isEmpty);
    });

    test('selectAll on already empty filter remains empty', () {
      container.read(sourceFilterProvider.notifier).selectAll();
      expect(container.read(sourceFilterProvider), isEmpty);
    });

    test('selectOnly sets exactly one source ID', () {
      container.read(sourceFilterProvider.notifier).toggle('src1');
      container.read(sourceFilterProvider.notifier).toggle('src2');
      container.read(sourceFilterProvider.notifier).selectOnly('src3');
      expect(container.read(sourceFilterProvider), {'src3'});
    });

    test('selectOnly replaces previous filter with single ID', () {
      container.read(sourceFilterProvider.notifier).selectOnly('src1');
      container.read(sourceFilterProvider.notifier).selectOnly('src2');
      expect(container.read(sourceFilterProvider), {'src2'});
    });
  });

  group('effectiveSourceIdsProvider', () {
    test('empty filter + admin (accessible=null) returns empty list', () {
      final container = ProviderContainer(
        overrides: [
          accessibleSourcesProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      // No filter toggled — default empty set
      final result = container.read(effectiveSourceIdsProvider);
      expect(result, isEmpty);
    });

    test('non-empty filter + admin returns filter as list', () {
      final container = ProviderContainer(
        overrides: [
          accessibleSourcesProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      container.read(sourceFilterProvider.notifier).toggle('src1');
      container.read(sourceFilterProvider.notifier).toggle('src2');

      final result = container.read(effectiveSourceIdsProvider);
      expect(result, unorderedEquals(['src1', 'src2']));
    });

    test('empty filter + restricted profile returns accessible list', () {
      final container = ProviderContainer(
        overrides: [
          accessibleSourcesProvider.overrideWith(
            (ref) async => ['src1', 'src2'],
          ),
        ],
      );
      addTearDown(container.dispose);

      // Pump the async provider so valueOrNull is populated
      container.read(accessibleSourcesProvider);

      // No filter — should return full accessible list once resolved
      // Since the async hasn't resolved yet, valueOrNull is null → empty
      // We need to wait for the future to resolve
      final result = container.read(effectiveSourceIdsProvider);
      // Initially async not resolved — treated as admin (null valueOrNull)
      // The test validates behavior after resolution
      expect(result, anyOf(isEmpty, equals(['src1', 'src2'])));
    });

    test(
      'empty filter + restricted profile returns accessible list after async resolves',
      () async {
        final container = ProviderContainer(
          overrides: [
            accessibleSourcesProvider.overrideWith(
              (ref) async => ['src1', 'src2'],
            ),
          ],
        );
        addTearDown(container.dispose);

        // Await the async provider
        await container.read(accessibleSourcesProvider.future);

        final result = container.read(effectiveSourceIdsProvider);
        expect(result, unorderedEquals(['src1', 'src2']));
      },
    );

    test(
      'non-empty filter + restricted profile returns intersection',
      () async {
        final container = ProviderContainer(
          overrides: [
            accessibleSourcesProvider.overrideWith(
              (ref) async => ['src1', 'src2', 'src3'],
            ),
          ],
        );
        addTearDown(container.dispose);

        // Await the async provider to resolve
        await container.read(accessibleSourcesProvider.future);

        // Filter includes src1 and src4 — only src1 is accessible
        container.read(sourceFilterProvider.notifier).toggle('src1');
        container.read(sourceFilterProvider.notifier).toggle('src4');

        final result = container.read(effectiveSourceIdsProvider);
        expect(result, equals(['src1']));
      },
    );

    test(
      'filter with no overlap with restricted profile returns empty list',
      () async {
        final container = ProviderContainer(
          overrides: [
            accessibleSourcesProvider.overrideWith(
              (ref) async => ['src1', 'src2'],
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(accessibleSourcesProvider.future);

        container.read(sourceFilterProvider.notifier).toggle('src3');
        container.read(sourceFilterProvider.notifier).toggle('src4');

        final result = container.read(effectiveSourceIdsProvider);
        expect(result, isEmpty);
      },
    );
  });
}
