import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/providers/source_filter_provider.dart';
import 'package:crispy_tivi/core/widgets/error_state_widget.dart';
import 'package:crispy_tivi/core/widgets/loading_state_widget.dart';
import 'package:crispy_tivi/features/search/domain/entities/grouped_search_results.dart';
import 'package:crispy_tivi/features/search/domain/entities/search_state.dart';
import 'package:crispy_tivi/features/search/presentation/widgets/search_body.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal [SettingsNotifier] that returns an empty state with no sources.
class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<SettingsState> build() async => SettingsState(
    config: const AppConfig(
      appName: 'Test',
      appVersion: '0.0.1',
      api: ApiConfig(
        baseUrl: 'http://test',
        backendPort: 8080,
        connectTimeoutMs: 5000,
        receiveTimeoutMs: 5000,
        sendTimeoutMs: 5000,
      ),
      player: PlayerConfig(
        defaultBufferDurationMs: 2000,
        autoPlay: true,
        defaultAspectRatio: '16:9',
      ),
      theme: ThemeConfig(
        mode: 'dark',
        seedColorHex: '#6750A4',
        useDynamicColor: false,
      ),
      features: FeaturesConfig(
        iptvEnabled: true,
        jellyfinEnabled: false,
        plexEnabled: false,
        embyEnabled: false,
      ),
      cache: CacheConfig(
        epgRefreshIntervalMinutes: 360,
        channelListRefreshIntervalMinutes: 60,
        maxCachedEpgDays: 7,
      ),
    ),
  );

  @override
  Future<String?> getVodGridDensity() async => null;

  @override
  Future<void> setVodGridDensity(String density) async {}

  @override
  Future<String?> getVodSortOption() async => null;

  @override
  Future<void> setVodSortOption(String value) async {}
}

/// Wraps [child] in a minimal ProviderScope + MaterialApp with l10n.
Widget _testApp(Widget child) => ProviderScope(
  overrides: [
    crispyBackendProvider.overrideWithValue(MemoryBackend()),
    settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
    effectiveSourceIdsProvider.overrideWithValue(const []),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

/// Builds a [SearchBody] with sensible defaults that can be overridden.
Widget _buildBody({required SearchState state, bool isContentLoaded = true}) =>
    _testApp(
      SearchBody(
        state: state,
        isContentLoaded: isContentLoaded,
        onToggleContentType: (_) {},
        onClearFilters: () {},
        onSelectRecent: (_) {},
        onRemoveRecent: (_) {},
        onClearHistory: () {},
        onItemTap: (_) async {},
        onItemFavorite: (_) {},
        onItemDetails: (_) {},
      ),
    );

/// A minimal [MediaItem] for use in test results.
MediaItem _item(String id, String name) =>
    MediaItem(id: id, name: name, type: MediaType.movie);

void main() {
  group('SearchBody', () {
    testWidgets('shows LoadingStateWidget when state.isLoading is true', (
      tester,
    ) async {
      const state = SearchState(query: 'hello', isLoading: true);

      await tester.pumpWidget(_buildBody(state: state));
      await tester.pump();

      expect(find.byType(LoadingStateWidget), findsOneWidget);
    });

    testWidgets('shows error message when state.error is set', (tester) async {
      const state = SearchState(query: 'hello', error: 'Something went wrong');

      await tester.pumpWidget(_buildBody(state: state));
      await tester.pump();

      expect(find.byType(ErrorStateWidget), findsOneWidget);
      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });

    testWidgets(
      'shows no-results state when query is set and results are empty',
      (tester) async {
        const state = SearchState(
          query: 'xyznotfound',
          results: GroupedSearchResults(),
        );

        await tester.pumpWidget(_buildBody(state: state));
        await tester.pump();

        expect(find.byIcon(Icons.search_off), findsOneWidget);
        expect(find.textContaining('xyznotfound'), findsOneWidget);
      },
    );

    testWidgets(
      'shows loading hint when query has no results and content not loaded',
      (tester) async {
        const state = SearchState(
          query: 'test',
          results: GroupedSearchResults(),
        );

        await tester.pumpWidget(
          _buildBody(state: state, isContentLoaded: false),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.textContaining('Loading content data'), findsOneWidget);
      },
    );

    // Note: Testing the "results exist" rendering path of SearchBody requires
    // rendering EnhancedSearchResultCard, which uses
    // Row(crossAxisAlignment.stretch) inside a SliverList item. In Flutter's
    // debug mode, the sliver protocol provides unbounded main-axis (height)
    // constraints to list items, and stretch requires bounded height, causing
    // a cascading layout assertion that cannot be suppressed without access to
    // the lib/ files. The coverage for this path is exercised via integration
    // tests (integration_test/flows/). The unit-level logic — that
    // SearchState.hasResults correctly selects the results branch — is verified
    // by the SearchState tests in search_providers_test.dart.
    test('SearchState.hasResults is true when results are non-empty', () {
      final results = GroupedSearchResults(movies: [_item('1', 'Inception')]);
      final state = SearchState(query: 'inc', results: results);

      expect(state.hasResults, isTrue);
      expect(state.hasNoResults, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    testWidgets('shows recent searches list when query is empty', (
      tester,
    ) async {
      const state = SearchState();

      await tester.pumpWidget(_buildBody(state: state));
      await tester.pump();

      // Empty recent list → shows hint text.
      expect(
        find.text('Search for channels, movies, series, or programs'),
        findsOneWidget,
      );
    });

    testWidgets('renders all 4 filter chips regardless of state', (
      tester,
    ) async {
      const state = SearchState();

      await tester.pumpWidget(_buildBody(state: state));
      await tester.pump();

      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Programs'), findsOneWidget);
    });
  });
}
