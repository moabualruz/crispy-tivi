import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/data/watch_history_service.dart';
import 'package:crispy_tivi/features/player/domain/entities/watch_history_entry.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/vod/presentation/screens/series_browser_screen.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SeriesBrowserScreen search renders filtered in-memory results', (
    tester,
  ) async {
    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SeriesBrowserScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          crispyBackendProvider.overrideWithValue(testBackend),
          cacheServiceProvider.overrideWithValue(testCache),
          vodProvider.overrideWith(_FakeSeriesVodNotifier.new),
          seriesWithNewEpisodesProvider.overrideWithValue(const <String>{}),
          continueWatchingSeriesProvider.overrideWith(
            (ref) async => <WatchHistoryEntry>[],
          ),
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

    expect(find.text('Alpha Files'), findsOneWidget);
    expect(find.text('Alpha Squad'), findsOneWidget);
    expect(find.text('Beta Stories'), findsNothing);
  });
}

class _FakeSeriesVodNotifier extends VodNotifier {
  @override
  VodState build() {
    return VodState(
      items: const [
        VodItem(
          id: 'series-alpha-1',
          name: 'Alpha Files',
          streamUrl: 'http://test/series-alpha-1',
          type: VodType.series,
          category: 'Drama',
        ),
        VodItem(
          id: 'series-alpha-2',
          name: 'Alpha Squad',
          streamUrl: 'http://test/series-alpha-2',
          type: VodType.series,
          category: 'Drama',
        ),
        VodItem(
          id: 'series-beta-1',
          name: 'Beta Stories',
          streamUrl: 'http://test/series-beta-1',
          type: VodType.series,
          category: 'Comedy',
        ),
      ],
      categories: const ['Comedy', 'Drama'],
    );
  }
}
