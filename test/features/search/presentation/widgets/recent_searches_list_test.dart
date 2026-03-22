import 'package:crispy_tivi/features/search/domain/entities/search_history_entry.dart';
import 'package:crispy_tivi/features/search/presentation/widgets/recent_searches_list.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimum widget tree needed for widget tests.
Widget _testApp(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

SearchHistoryEntry _entry({
  required String id,
  required String query,
  int resultCount = 0,
}) => SearchHistoryEntry(
  id: id,
  query: query,
  searchedAt: DateTime(2026, 1, 1),
  resultCount: resultCount,
);

void main() {
  group('RecentSearchesList', () {
    testWidgets('renders recent search items with correct titles', (
      tester,
    ) async {
      final entries = [
        _entry(id: '1', query: 'Breaking Bad'),
        _entry(id: '2', query: 'BBC News'),
      ];

      await tester.pumpWidget(
        _testApp(
          RecentSearchesList(
            entries: entries,
            onSelect: (_) {},
            onRemove: (_) {},
            onClearAll: () {},
          ),
        ),
      );

      expect(find.text('Breaking Bad'), findsOneWidget);
      expect(find.text('BBC News'), findsOneWidget);
    });

    testWidgets('tapping an item calls onSelect with the entry', (
      tester,
    ) async {
      final entry = _entry(id: '1', query: 'Star Wars');
      SearchHistoryEntry? selected;

      await tester.pumpWidget(
        _testApp(
          RecentSearchesList(
            entries: [entry],
            onSelect: (e) => selected = e,
            onRemove: (_) {},
            onClearAll: () {},
          ),
        ),
      );

      await tester.tap(find.text('Star Wars'));
      await tester.pump();

      expect(selected, equals(entry));
    });

    testWidgets('tapping clear all button calls onClearAll', (tester) async {
      var clearAllCalled = false;

      await tester.pumpWidget(
        _testApp(
          RecentSearchesList(
            entries: [_entry(id: '1', query: 'test')],
            onSelect: (_) {},
            onRemove: (_) {},
            onClearAll: () => clearAllCalled = true,
          ),
        ),
      );

      await tester.tap(find.text('Clear All'));
      await tester.pump();

      expect(clearAllCalled, isTrue);
    });

    testWidgets('tapping remove icon calls onRemove with the entry id', (
      tester,
    ) async {
      final entry = _entry(id: 'entry-42', query: 'CNN');
      String? removedId;

      await tester.pumpWidget(
        _testApp(
          RecentSearchesList(
            entries: [entry],
            onSelect: (_) {},
            onRemove: (id) => removedId = id,
            onClearAll: () {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removedId, equals('entry-42'));
    });

    testWidgets('empty state shows hint text when entries list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          RecentSearchesList(
            entries: const [],
            onSelect: (_) {},
            onRemove: (_) {},
            onClearAll: () {},
          ),
        ),
      );

      expect(
        find.text('Search for channels, movies, series, or programs'),
        findsOneWidget,
      );
    });

    testWidgets('empty state does not show recent searches header', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          RecentSearchesList(
            entries: const [],
            onSelect: (_) {},
            onRemove: (_) {},
            onClearAll: () {},
          ),
        ),
      );

      expect(find.text('Recent Searches'), findsNothing);
    });

    testWidgets('non-empty state shows recent searches header', (tester) async {
      await tester.pumpWidget(
        _testApp(
          RecentSearchesList(
            entries: [_entry(id: '1', query: 'Discovery')],
            onSelect: (_) {},
            onRemove: (_) {},
            onClearAll: () {},
          ),
        ),
      );

      expect(find.text('Recent Searches'), findsOneWidget);
    });
  });
}
