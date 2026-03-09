import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/providers/source_filter_provider.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_favorites_provider.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/vod/presentation/screens/vod_details_screen.dart';

/// In-memory VOD favorites controller for testing.
class _TestVodFavoritesController extends VodFavoritesController {
  @override
  Future<Set<String>> build() async => {};

  @override
  Future<void> toggleFavorite(String vodItemId) async {
    final current = state.value ?? {};
    if (current.contains(vodItemId)) {
      state = AsyncData({...current}..remove(vodItemId));
    } else {
      state = AsyncData({...current, vodItemId});
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockItem = VodItem(
    id: 'movie1',
    name: 'Test Movie',
    streamUrl: 'http://test',
    type: VodType.movie,
    description: 'A test movie description',
    year: 2024,
    rating: '8.5',
    duration: 120,
    category: 'Action',
    isFavorite: false,
  );

  testWidgets('VodDetailsScreen renders correct info and handles interaction', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => VodDetailsScreen(item: mockItem),
        ),
        GoRoute(
          path: '/player',
          builder:
              (context, state) => const Scaffold(body: Text('Player Screen')),
        ),
      ],
    );

    addTearDown(router.dispose);

    final testBackend = MemoryBackend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          crispyBackendProvider.overrideWithValue(testBackend),
          vodFavoritesProvider.overrideWith(_TestVodFavoritesController.new),
          effectiveSourceIdsProvider.overrideWithValue(const []),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    // Initialize provider with data
    final element = tester.element(find.byType(VodDetailsScreen));
    final container = ProviderScope.containerOf(element);
    container.read(vodProvider.notifier).loadData([mockItem]);

    await tester.pumpAndSettle();

    // 1. Verify rendering
    // Title + description appear once each.
    expect(find.text('Test Movie'), findsOneWidget);
    expect(find.text('A test movie description'), findsOneWidget);
    // Metadata appears in the hero chips AND in the
    // body metadata column, so expect at least one.
    expect(find.text('2024'), findsWidgets);
    expect(find.text('8.5'), findsWidgets);
    expect(find.text('2h 0m'), findsWidgets);
    expect(find.text('Action'), findsWidgets);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('My List'), findsOneWidget);

    // 2. Verify Favorite Interaction
    // Scroll down to reveal action buttons below hero
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My List'));
    await tester.pumpAndSettle();

    final updatedState = container.read(vodProvider);
    final updatedItem = updatedState.items.firstWhere((i) => i.id == 'movie1');
    expect(updatedItem.isFavorite, isTrue);

    // 3. Verify Play button exists (tapping triggers database
    // init via watchHistoryService which can't be tested without
    // mocking the database provider).
    expect(find.text('Play'), findsOneWidget);
  });
}
