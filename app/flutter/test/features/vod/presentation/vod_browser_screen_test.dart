import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/data/watch_history_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/watch_history_entry.dart';
import 'package:crispy_tivi/features/recommendations/presentation/providers/recommendation_providers.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/vod/presentation/screens/vod_browser_screen.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

    expect(find.text('Series'), findsNothing);
    expect(find.text('Test Movie'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Action'), findsWidgets);
  });

  testWidgets('VodBrowserScreen search renders filtered in-memory results', (
    tester,
  ) async {
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
          vodProvider.overrideWith(_SearchableVodNotifier.new),
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
    await tester.enterText(find.byType(TextField).first, 'alpha');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Alpha One'), findsOneWidget);
    expect(find.text('Alpha Two'), findsOneWidget);
    expect(find.text('Beta Only'), findsNothing);
  });
}

class _FakeVodNotifier extends VodNotifier {
  @override
  VodState build() {
    return VodState(
      items: const [
        VodItem(
          id: '1',
          name: 'Test Movie',
          streamUrl: 'http://test/vod/1',
          type: VodType.movie,
          category: 'Action',
          isFavorite: true,
        ),
        VodItem(
          id: '2',
          name: 'Test Series',
          streamUrl: 'http://test/vod/2',
          type: VodType.series,
          category: 'Drama',
        ),
      ],
      categories: const ['Action', 'Drama'],
    );
  }
}

class _SearchableVodNotifier extends VodNotifier {
  @override
  VodState build() {
    return VodState(
      items: const [
        VodItem(
          id: 'alpha-1',
          name: 'Alpha One',
          streamUrl: 'http://test/vod/alpha-1',
          type: VodType.movie,
          category: 'Action',
        ),
        VodItem(
          id: 'alpha-2',
          name: 'Alpha Two',
          streamUrl: 'http://test/vod/alpha-2',
          type: VodType.movie,
          category: 'Action',
        ),
        VodItem(
          id: 'beta-1',
          name: 'Beta Only',
          streamUrl: 'http://test/vod/beta-1',
          type: VodType.movie,
          category: 'Drama',
        ),
      ],
      categories: const ['Action', 'Drama'],
    );
  }
}
