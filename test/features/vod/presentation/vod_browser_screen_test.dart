import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/data/watch_history_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/watch_history_entry.dart';
import 'package:crispy_tivi/features/recommendations/presentation/providers/recommendation_providers.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/vod/presentation/screens/vod_browser_screen.dart';

/// Fake VOD notifier with pre-loaded data for widget tests.
class _FakeVodNotifier extends VodNotifier {
  @override
  VodState build() {
    return VodState(
      items: [
        VodItem(
          id: 'movie1',
          name: 'Test Movie',
          streamUrl: 'http://test',
          type: VodType.movie,
          category: 'Action',
          isFavorite: true,
        ),
      ],
      categories: ['Action'],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VodBrowserScreen renders movies-only swimlanes', (tester) async {
    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const VodBrowserScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          crispyBackendProvider.overrideWithValue(testBackend),
          cacheServiceProvider.overrideWithValue(testCache),
          vodProvider.overrideWith(_FakeVodNotifier.new),
          continueWatchingMoviesProvider.overrideWith(
            (ref) async => <WatchHistoryEntry>[],
          ),
          continueWatchingSeriesProvider.overrideWith(
            (ref) async => <WatchHistoryEntry>[],
          ),
          vodRecommendationsProvider.overrideWithValue(const []),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // No Series tab (movies-only since V2)
    expect(find.text('Series'), findsNothing);

    // Verify Favorites section (mockMovie is favorite)
    expect(find.text('Favorites'), findsOneWidget);

    // Verify Test Movie appears in Favorites + category swimlane
    expect(find.text('Test Movie'), findsNWidgets(2));

    // Verify "All" genre chip (first chip in GenrePillRow is always 'All')
    expect(find.text('All'), findsOneWidget);

    // Verify category swimlane (Action appears as genre chip + swimlane title)
    expect(find.text('Action'), findsWidgets);
  });
}
