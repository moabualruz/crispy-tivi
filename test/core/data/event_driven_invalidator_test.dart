import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/event_bus_provider.dart';
import 'package:crispy_tivi/core/data/event_driven_invalidator.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/'
    'channel_providers.dart';
import 'package:crispy_tivi/features/favorites/presentation/providers/'
    'favorites_controller.dart';
import 'package:crispy_tivi/features/multiview/presentation/providers/'
    'multiview_providers.dart';
import 'package:crispy_tivi/features/player/data/watch_history_service.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/'
    'vod_favorites_provider.dart';

// ── Build counters ─────────────────────────────────────────────
// Each spy provider increments its counter when it (re-)builds.
// A counter increase after an event proves invalidation happened.

int _channelBuilds = 0;
int _moviesBuilds = 0;
int _seriesBuilds = 0;
int _favoritesBuilds = 0;
int _savedLayoutsBuilds = 0;
int _vodFavoritesBuilds = 0;

// ── Spy notifiers ──────────────────────────────────────────────

class _SpyChannelListNotifier extends ChannelListNotifier {
  @override
  ChannelListState build() {
    _channelBuilds++;
    return const ChannelListState();
  }

  @override
  Future<void> refreshFromBackend() async {
    // Track refresh calls via the same counter so
    // existing assertions work unchanged.
    _channelBuilds++;
  }
}

class _SpyFavoritesController extends FavoritesController {
  @override
  Future<List<Channel>> build() async {
    _favoritesBuilds++;
    return [];
  }
}

class _SpyVodFavoritesController extends VodFavoritesController {
  @override
  Future<Set<String>> build() async {
    _vodFavoritesBuilds++;
    return {};
  }
}

// ── Container factory ──────────────────────────────────────────

/// Build a test [ProviderContainer] with:
/// - [MemoryBackend] wired to [crispyBackendProvider]
/// - Spy overrides that count builds for each provider
/// - An external listener on [eventBusProvider] to activate
///   the stream subscription (required for ref.listen in the
///   invalidator to fire)
/// - Listeners on every FutureProvider under test (required
///   for FutureProviders to rebuild on invalidation)
///
/// Returns the container already primed: every tracked provider
/// has been built once. Call [_buildCounts] to snapshot counters.
ProviderContainer _makeContainer(MemoryBackend backend) {
  final container = ProviderContainer(
    overrides: [
      crispyBackendProvider.overrideWithValue(backend),
      channelListProvider.overrideWith(_SpyChannelListNotifier.new),
      favoritesControllerProvider.overrideWith(_SpyFavoritesController.new),
      vodFavoritesProvider.overrideWith(_SpyVodFavoritesController.new),
      continueWatchingMoviesProvider.overrideWith((_) async {
        _moviesBuilds++;
        return [];
      }),
      continueWatchingSeriesProvider.overrideWith((_) async {
        _seriesBuilds++;
        return [];
      }),
      savedLayoutsProvider.overrideWith((_) async {
        _savedLayoutsBuilds++;
        return [];
      }),
    ],
  );

  // CRITICAL: Listen to eventBusProvider BEFORE activating the
  // invalidator. This ensures the StreamProvider is subscribed
  // so its emitted values reach the invalidator's ref.listen.
  container.listen(eventBusProvider, (prev, next) {}, fireImmediately: true);

  // Activate the invalidator (wires ref.listen on eventBusProvider).
  container.read(eventDrivenInvalidatorProvider);

  // Prime all providers — each builds once.
  container.read(channelListProvider);
  container.listen(continueWatchingMoviesProvider, (prev, next) {});
  container.listen(continueWatchingSeriesProvider, (prev, next) {});
  container.listen(favoritesControllerProvider, (prev, next) {});
  container.listen(savedLayoutsProvider, (prev, next) {});
  container.listen(vodFavoritesProvider, (prev, next) {});

  return container;
}

/// Snapshot all build counters.
_Counts _snapshot() => _Counts(
  channel: _channelBuilds,
  movies: _moviesBuilds,
  series: _seriesBuilds,
  favorites: _favoritesBuilds,
  layouts: _savedLayoutsBuilds,
  vodFavorites: _vodFavoritesBuilds,
);

class _Counts {
  _Counts({
    required this.channel,
    required this.movies,
    required this.series,
    required this.favorites,
    required this.layouts,
    required this.vodFavorites,
  });

  final int channel;
  final int movies;
  final int series;
  final int favorites;
  final int layouts;
  final int vodFavorites;
}

// ── Test helpers ──────────────────────────────────────────────

/// Emit JSON and drain microtasks so the stream listener +
/// invalidator callback both execute. Does NOT advance past
/// the debounce window — use for bulk events that bypass it.
Future<void> emitImmediate(MemoryBackend backend, String json) async {
  backend.emitTestEvent(json);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// Emit JSON, drain microtasks, then wait 60 ms for the 50 ms
/// debounce timer to fire, then drain again.
Future<void> emitAndWaitDebounce(MemoryBackend backend, String json) async {
  backend.emitTestEvent(json);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late MemoryBackend backend;
  late ProviderContainer container;

  setUp(() async {
    _channelBuilds = 0;
    _moviesBuilds = 0;
    _seriesBuilds = 0;
    _favoritesBuilds = 0;
    _savedLayoutsBuilds = 0;
    _vodFavoritesBuilds = 0;

    backend = MemoryBackend();
    await backend.init('');
    container = _makeContainer(backend);
  });

  tearDown(() => container.dispose());

  // ── Tests ──────────────────────────────────────────────────

  group('EventDrivenInvalidator', () {
    test('ChannelsUpdated invalidates channelListProvider', () async {
      final before = _snapshot();

      await emitAndWaitDebounce(
        backend,
        '{"type":"ChannelsUpdated","source_id":"s1"}',
      );

      container.read(channelListProvider);
      expect(_channelBuilds, greaterThan(before.channel));
    });

    test('CategoriesUpdated invalidates channelListProvider', () async {
      final before = _snapshot();

      await emitAndWaitDebounce(
        backend,
        '{"type":"CategoriesUpdated","source_id":"s2"}',
      );

      container.read(channelListProvider);
      expect(_channelBuilds, greaterThan(before.channel));
    });

    test('ChannelOrderChanged invalidates channelListProvider', () async {
      final before = _snapshot();

      await emitAndWaitDebounce(backend, '{"type":"ChannelOrderChanged"}');

      container.read(channelListProvider);
      expect(_channelBuilds, greaterThan(before.channel));
    });

    test('WatchHistoryUpdated invalidates continueWatchingMovies', () async {
      final before = _snapshot();

      await emitAndWaitDebounce(
        backend,
        '{"type":"WatchHistoryUpdated","channel_id":"ch-55"}',
      );

      expect(_moviesBuilds, greaterThan(before.movies));
    });

    test('WatchHistoryUpdated invalidates continueWatchingSeries', () async {
      final before = _snapshot();

      await emitAndWaitDebounce(
        backend,
        '{"type":"WatchHistoryUpdated","channel_id":"ch-55"}',
      );

      expect(_seriesBuilds, greaterThan(before.series));
    });

    test(
      'WatchHistoryCleared invalidates both continueWatching providers',
      () async {
        final before = _snapshot();

        await emitAndWaitDebounce(backend, '{"type":"WatchHistoryCleared"}');

        expect(_moviesBuilds, greaterThan(before.movies));
        expect(_seriesBuilds, greaterThan(before.series));
      },
    );

    test('FavoriteToggled invalidates favoritesControllerProvider', () async {
      final before = _snapshot();

      await emitAndWaitDebounce(
        backend,
        '{"type":"FavoriteToggled","item_id":"ch7","is_favorite":true}',
      );

      expect(_favoritesBuilds, greaterThan(before.favorites));
    });

    test('VodFavoriteToggled invalidates vodFavoritesProvider', () async {
      final before = _snapshot();

      await emitAndWaitDebounce(
        backend,
        '{"type":"VodFavoriteToggled","vod_id":"v42","is_favorite":false}',
      );

      expect(_vodFavoritesBuilds, greaterThan(before.vodFavorites));
    });

    test(
      'VodWatchProgressUpdated invalidates continueWatchingMovies',
      () async {
        final before = _snapshot();

        await emitAndWaitDebounce(
          backend,
          '{"type":"VodWatchProgressUpdated","vod_id":"v-prog-1"}',
        );

        expect(_moviesBuilds, greaterThan(before.movies));
      },
    );

    test('SavedLayoutChanged invalidates savedLayoutsProvider', () async {
      final before = _snapshot();

      await emitAndWaitDebounce(backend, '{"type":"SavedLayoutChanged"}');

      expect(_savedLayoutsBuilds, greaterThan(before.layouts));
    });

    test('BulkDataRefresh invalidates all major providers', () async {
      final before = _snapshot();

      // BulkDataRefresh bypasses debounce — fires immediately.
      await emitImmediate(backend, '{"type":"BulkDataRefresh"}');

      container.read(channelListProvider);
      expect(_channelBuilds, greaterThan(before.channel));
      expect(_moviesBuilds, greaterThan(before.movies));
      expect(_favoritesBuilds, greaterThan(before.favorites));
      expect(_savedLayoutsBuilds, greaterThan(before.layouts));
      expect(_vodFavoritesBuilds, greaterThan(before.vodFavorites));
    });

    test('CloudSyncCompleted invalidates all major providers', () async {
      final before = _snapshot();

      // CloudSyncCompleted bypasses debounce — fires immediately.
      await emitImmediate(backend, '{"type":"CloudSyncCompleted"}');

      container.read(channelListProvider);
      expect(_channelBuilds, greaterThan(before.channel));
      expect(_savedLayoutsBuilds, greaterThan(before.layouts));
    });

    test(
      'UnknownEvent is silently ignored — no providers are rebuilt',
      () async {
        final before = _snapshot();

        await emitAndWaitDebounce(
          backend,
          '{"type":"ThisEventTypeDoesNotExist","x":1}',
        );

        // No re-reads — counters must not change.
        expect(_channelBuilds, equals(before.channel));
        expect(_savedLayoutsBuilds, equals(before.layouts));
        expect(_favoritesBuilds, equals(before.favorites));
      },
    );

    test('SearchHistoryChanged does not invalidate cached providers', () async {
      final before = _snapshot();

      await emitAndWaitDebounce(backend, '{"type":"SearchHistoryChanged"}');

      expect(_channelBuilds, equals(before.channel));
      expect(_savedLayoutsBuilds, equals(before.layouts));
    });

    test(
      'multiple sequential events each invalidate correct providers',
      () async {
        final before = _snapshot();

        // Event 1: channels only.
        await emitAndWaitDebounce(
          backend,
          '{"type":"ChannelsUpdated","source_id":"s1"}',
        );
        container.read(channelListProvider);
        expect(_channelBuilds, greaterThan(before.channel));
        final ch1 = _channelBuilds;

        // Event 2: watch history → movies & series only.
        await emitAndWaitDebounce(
          backend,
          '{"type":"WatchHistoryUpdated","channel_id":"c9"}',
        );
        expect(_moviesBuilds, greaterThan(before.movies));
        expect(_seriesBuilds, greaterThan(before.series));
        // Channel should NOT have been invalidated again.
        expect(_channelBuilds, equals(ch1));

        // Event 3: VOD favorites only.
        await emitAndWaitDebounce(
          backend,
          '{"type":"VodFavoriteToggled","vod_id":"v7","is_favorite":true}',
        );
        expect(_vodFavoritesBuilds, greaterThan(before.vodFavorites));
      },
    );

    test('FavoriteCategoryToggled does not crash', () async {
      // This event invalidates a family provider
      // (favoriteCategoriesProvider(categoryType)). We only
      // verify no crash and that unrelated providers are untouched.
      final before = _snapshot();

      await emitAndWaitDebounce(
        backend,
        '{"type":"FavoriteCategoryToggled",'
        '"category_type":"live","category_name":"Sports"}',
      );

      // Unrelated providers must not be invalidated.
      expect(_channelBuilds, equals(before.channel));
      expect(_savedLayoutsBuilds, equals(before.layouts));
    });

    // ── Debounce-specific tests ───────────────────────────

    group('debounce', () {
      test('BulkDataRefresh bypasses debounce and fires immediately', () async {
        final before = _snapshot();

        // Emit and only drain microtasks — no timer wait.
        await emitImmediate(backend, '{"type":"BulkDataRefresh"}');

        // Must have fired without waiting for debounce.
        container.read(channelListProvider);
        expect(_channelBuilds, greaterThan(before.channel));
        expect(_moviesBuilds, greaterThan(before.movies));
      });

      test(
        'CloudSyncCompleted bypasses debounce and fires immediately',
        () async {
          final before = _snapshot();

          await emitImmediate(backend, '{"type":"CloudSyncCompleted"}');

          container.read(channelListProvider);
          expect(_channelBuilds, greaterThan(before.channel));
          expect(_savedLayoutsBuilds, greaterThan(before.layouts));
        },
      );

      test('rapid duplicate events are coalesced: only one '
          'invalidation per type in a burst', () async {
        // Emit ChannelsUpdated three times rapidly (< 50 ms apart).
        // All three should be coalesced into one invalidation.
        backend.emitTestEvent('{"type":"ChannelsUpdated","source_id":"s1"}');
        backend.emitTestEvent('{"type":"ChannelsUpdated","source_id":"s2"}');
        backend.emitTestEvent('{"type":"ChannelsUpdated","source_id":"s3"}');

        // Drain microtasks so stream events are received by
        // the invalidator's ref.listen, but do NOT wait for
        // the 50 ms timer yet.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Snapshot before debounce fires — channel count
        // should still be at its primed value.
        final countBeforeFire = _channelBuilds;

        // Now wait for the debounce window to expire.
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await Future<void>.delayed(Duration.zero);

        // Read to trigger rebuild.
        container.read(channelListProvider);

        // Channel was invalidated exactly once (deduplicated).
        // Build count must increase by exactly 1.
        expect(_channelBuilds, equals(countBeforeFire + 1));
      });

      test('different event types are all dispatched after debounce', () async {
        final before = _snapshot();

        // Emit three distinct event types within the debounce
        // window (no timer between them).
        backend.emitTestEvent('{"type":"ChannelsUpdated","source_id":"s1"}');
        backend.emitTestEvent('{"type":"WatchHistoryCleared"}');
        backend.emitTestEvent(
          '{"type":"VodFavoriteToggled",'
          '"vod_id":"v1","is_favorite":true}',
        );

        // Drain microtasks only.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Snapshot mid-debounce — providers not yet rebuilt.
        final channelMid = _channelBuilds;
        final moviesMid = _moviesBuilds;
        final vodMid = _vodFavoritesBuilds;

        // Advance past debounce.
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await Future<void>.delayed(Duration.zero);

        // All three event types must have been dispatched.
        container.read(channelListProvider);
        expect(_channelBuilds, greaterThan(channelMid));
        expect(_moviesBuilds, greaterThan(moviesMid));
        expect(_seriesBuilds, greaterThan(before.series));
        expect(_vodFavoritesBuilds, greaterThan(vodMid));
      });

      test('events within debounce window are not processed until '
          'timer elapses', () async {
        final before = _snapshot();

        backend.emitTestEvent('{"type":"ChannelsUpdated","source_id":"s1"}');

        // Drain microtasks — stream received but timer not
        // yet expired.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // No invalidation yet.
        container.read(channelListProvider);
        expect(_channelBuilds, equals(before.channel));

        // Wait past 50 ms — debounce fires.
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await Future<void>.delayed(Duration.zero);

        container.read(channelListProvider);
        expect(_channelBuilds, greaterThan(before.channel));
      });
    });
  });
}
