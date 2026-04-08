import 'package:crispy_tivi/features/search/domain/entities/search_filter.dart';
import 'package:crispy_tivi/features/search/presentation/widgets/content_type_filter_row.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimum widget tree needed for widget tests.
Widget _testApp(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('ContentTypeFilterRow', () {
    testWidgets('renders all 4 filter chips', (tester) async {
      await tester.pumpWidget(
        _testApp(
          ContentTypeFilterRow(filter: const SearchFilter(), onToggle: (_) {}),
        ),
      );

      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Programs'), findsOneWidget);
    });

    testWidgets('tapping Channels chip calls onToggle with channels type', (
      tester,
    ) async {
      SearchContentType? toggled;

      await tester.pumpWidget(
        _testApp(
          ContentTypeFilterRow(
            filter: const SearchFilter(),
            onToggle: (type) => toggled = type,
          ),
        ),
      );

      await tester.tap(find.text('Channels'));
      await tester.pump();

      expect(toggled, SearchContentType.channels);
    });

    testWidgets('tapping Movies chip calls onToggle with movies type', (
      tester,
    ) async {
      SearchContentType? toggled;

      await tester.pumpWidget(
        _testApp(
          ContentTypeFilterRow(
            filter: const SearchFilter(),
            onToggle: (type) => toggled = type,
          ),
        ),
      );

      await tester.tap(find.text('Movies'));
      await tester.pump();

      expect(toggled, SearchContentType.movies);
    });

    testWidgets('tapping Series chip calls onToggle with series type', (
      tester,
    ) async {
      SearchContentType? toggled;

      await tester.pumpWidget(
        _testApp(
          ContentTypeFilterRow(
            filter: const SearchFilter(),
            onToggle: (type) => toggled = type,
          ),
        ),
      );

      await tester.tap(find.text('Series'));
      await tester.pump();

      expect(toggled, SearchContentType.series);
    });

    testWidgets('tapping Programs chip calls onToggle with epg type', (
      tester,
    ) async {
      SearchContentType? toggled;

      await tester.pumpWidget(
        _testApp(
          ContentTypeFilterRow(
            filter: const SearchFilter(),
            onToggle: (type) => toggled = type,
          ),
        ),
      );

      await tester.tap(find.text('Programs'));
      await tester.pump();

      expect(toggled, SearchContentType.epg);
    });

    testWidgets('selected chip shows selected state via FilterChip', (
      tester,
    ) async {
      const filter = SearchFilter(contentTypes: {SearchContentType.channels});

      await tester.pumpWidget(
        _testApp(ContentTypeFilterRow(filter: filter, onToggle: (_) {})),
      );

      // Find the FilterChip associated with "Channels".
      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      final channelsChip = chips.firstWhere((chip) {
        // The label is a Row; look for a Text descendant with "Channels".
        final row = chip.label as Row;
        return row.children.any((w) => w is Text && w.data == 'Channels');
      });

      expect(channelsChip.selected, isTrue);
    });

    testWidgets('unselected chip shows unselected state via FilterChip', (
      tester,
    ) async {
      const filter = SearchFilter(contentTypes: {SearchContentType.channels});

      await tester.pumpWidget(
        _testApp(ContentTypeFilterRow(filter: filter, onToggle: (_) {})),
      );

      // Movies should NOT be selected.
      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      final moviesChip = chips.firstWhere((chip) {
        final row = chip.label as Row;
        return row.children.any((w) => w is Text && w.data == 'Movies');
      });

      expect(moviesChip.selected, isFalse);
    });
  });
}
