import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/providers/source_filter_provider.dart';
import 'package:crispy_tivi/core/widgets/focus_wrapper.dart';
import 'package:crispy_tivi/features/player/data/watch_history_service.dart';
import 'package:crispy_tivi/features/recommendations/domain/entities/recommendation.dart';
import 'package:crispy_tivi/features/recommendations/presentation/providers/recommendation_providers.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_paginated_providers.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_favorites_provider.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/vod/presentation/screens/vod_browser_screen.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal settings notifier that does not require [CacheService] or
/// [CrispyBackend] — avoids the late-field initialisation crash in
/// [SettingsNotifier._cache].
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

/// In-memory VOD favorites controller — avoids [CacheService] access.
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

  final mockMovie1 = VodItem(
    id: 'm1',
    name: 'Movie 1',
    streamUrl: 'url',
    type: VodType.movie,
    category: 'Action',
  );
  final mockMovie2 = VodItem(
    id: 'm2',
    name: 'Movie 2',
    streamUrl: 'url',
    type: VodType.movie,
    category: 'Action',
  );

  testWidgets('VodBrowserScreen handles TV focus traversal', (tester) async {
    // Enable physical key simulation
    tester.binding.focusManager.primaryFocus?.unfocus();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          crispyBackendProvider.overrideWithValue(MemoryBackend()),
          // Avoid CacheService/CrispyBackend dependency in SettingsNotifier.
          settingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier()),
          // Avoid CacheService/profileServiceProvider dependency in
          // VodFavoritesController.
          vodFavoritesProvider.overrideWith(_TestVodFavoritesController.new),
          // Override at the filtered level to bypass profileServiceProvider
          // and the full CacheService/CrispyBackend stack.
          filteredMoviesProvider.overrideWith(
            (ref) => [mockMovie1, mockMovie2],
          ),
          vodCountPaginatedProvider(
            const VodPageRequest(itemType: 'movie'),
          ).overrideWith((ref) async => 2),
          vodCategoriesPaginatedProvider(
            'movie',
          ).overrideWith((ref) async => [(name: 'Action', count: 2)]),
          vodPagePaginatedProvider(
            const VodPageRequest(
              itemType: 'movie',
              category: 'Action',
              sort: 'added_desc',
            ),
          ).overrideWith((ref) async => [mockMovie1, mockMovie2]),
          // Avoid CacheService/CrispyBackend via RecommendationEngine.
          vodRecommendationsProvider.overrideWith(
            (ref) => <RecommendationSection>[],
          ),
          continueWatchingMoviesProvider.overrideWith(
            (ref) => Future.value([]),
          ),
          continueWatchingSeriesProvider.overrideWith(
            (ref) => Future.value([]),
          ),
          effectiveSourceIdsProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const VodBrowserScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Movie 1'), findsOneWidget);
    expect(find.text('Movie 2'), findsOneWidget);
    expect(find.byType(FocusWrapper), findsAtLeastNWidgets(2));

    // Initial focus might not be set automatically unless logic does it.
    // In TV apps, usually specific widget requests focus or user presses key.

    // Simulate D-pad Down to enter the list
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    // Check if any focusable item has focus.
    // This is hard to assert without specific FocusNodes exposed.
    // But we can check if FocusManager.instance.primaryFocus is not null.

    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNotNull);

    // If we press Down again, focus should move.
    // This simple test verifies that focus logic (Shortcuts/Actions) isn't
    // crashing and that widgets are focusable.
  });
}
