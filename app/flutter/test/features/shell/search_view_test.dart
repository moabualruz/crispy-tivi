import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:crispy_tivi/features/shell/presentation/search/search_presentation_adapter.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/search_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search route shows live tv handoff by default', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final String source = await rootBundle.loadString(
      'assets/contracts/asset_search_runtime.json',
    );
    final SearchRuntimeSnapshot runtime = SearchRuntimeSnapshot.fromJsonString(
      source,
    );
    final state = SearchPresentationAdapter.build(runtime: runtime);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SearchView(state: state))),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('search-handoff-domain'))).data,
      'Live TV',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('search-handoff-title'))).data,
      'Arena Live',
    );
    expect(find.text('Open channel'), findsOneWidget);
  });

  testWidgets('search result selection updates canonical handoff detail', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final SearchRuntimeSnapshot runtime = _moviesFocusedRuntime();
    final state = SearchPresentationAdapter.build(runtime: runtime);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SearchView(state: state))),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('search-handoff-domain'))).data,
      'Movies',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('search-handoff-title'))).data,
      'The Last Harbor',
    );
    expect(find.text('Open movie'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-result-0-1')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('search-handoff-title'))).data,
      'Atlas Run',
    );
    expect(find.text('Open movie'), findsOneWidget);
  });

  testWidgets('search route surfaces the retained runtime query', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final SearchRuntimeSnapshot runtime = _moviesFocusedRuntime();
    final state = SearchPresentationAdapter.build(runtime: runtime);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SearchView(state: state))),
    );
    await tester.pumpAndSettle();

    expect(find.text('atlas'), findsOneWidget);
  });
}

SearchRuntimeSnapshot _moviesFocusedRuntime() {
  return SearchRuntimeSnapshot(
    title: 'CrispyTivi Search Runtime',
    version: '1',
    query: 'atlas',
    activeGroupTitle: 'Movies',
    groups: <SearchRuntimeGroupSnapshot>[
      const SearchRuntimeGroupSnapshot(
        title: 'Movies',
        summary: 'Movies matching the current query.',
        selected: true,
        results: <SearchRuntimeResultSnapshot>[
          SearchRuntimeResultSnapshot(
            title: 'The Last Harbor',
            caption: 'Thriller',
            sourceLabel: 'Movies',
            handoffLabel: 'Open movie',
          ),
          SearchRuntimeResultSnapshot(
            title: 'Atlas Run',
            caption: 'Action',
            sourceLabel: 'Movies',
            handoffLabel: 'Open movie',
          ),
        ],
      ),
    ],
    notes: const <String>['Test runtime snapshot.'],
  );
}
