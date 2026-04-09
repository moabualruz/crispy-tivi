import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/data/cache_service.dart';
import '../../../epg/data/epg_json_codec.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/domain/entities/watch_history_entry.dart';
import '../../../profiles/data/profile_service.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../../vod/domain/utils/vod_utils.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/home/domain/utils/upcoming_programs.dart';

export 'package:crispy_tivi/features/home/domain/utils/upcoming_programs.dart'
    show UpcomingProgram;
export '../../../player/data/watch_history_service.dart'
    show
        WatchHistoryService,
        continueWatchingMoviesProvider,
        crossDeviceWatchingProvider,
        watchHistoryServiceProvider;

// ── FE-H-08: Dismissed recommendations ──────────────────

/// Notifier that tracks item IDs dismissed via "Not interested"
/// for the duration of the session. Dismissals are ephemeral —
/// they reset on app restart (no persistence needed).
class DismissedRecommendationsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Marks [itemId] as dismissed so it is filtered from the row.
  void dismiss(String itemId) {
    state = {...state, itemId};
  }

  /// Restores [itemId] (undo action).
  void undoDismiss(String itemId) {
    state = state.difference({itemId});
  }
}

/// Session-scoped set of recommendation item IDs hidden by the
/// user via "Not interested". Populated by
/// [DismissedRecommendationsNotifier.dismiss].
final dismissedRecommendationsProvider =
    NotifierProvider<DismissedRecommendationsNotifier, Set<String>>(
      DismissedRecommendationsNotifier.new,
    );

/// Fetches the user's recently-watched channels from history.
///
/// Live TV channels have no meaningful playback position, so
/// [WatchHistoryService.getAll] is used (sorted by [lastWatched]
/// descending) rather than [getContinueWatching], which filters
/// for partially-watched VOD/episode items only.
final recentChannelsProvider = FutureProvider.autoDispose<List<Channel>>((
  ref,
) async {
  final historyService = ref.watch(watchHistoryServiceProvider);
  final cacheService = ref.watch(cacheServiceProvider);

  // All history is sorted by lastWatched descending; filter to channels only.
  final allHistory = await historyService.getAll();
  final recentChannelIds =
      allHistory
          .where((h) => h.mediaType == 'channel')
          .take(10)
          .map((h) => h.id)
          .toList();

  if (recentChannelIds.isEmpty) return [];

  // Resolve IDs to Channel entities, preserving history order.
  final channels = await cacheService.getChannelsByIds(recentChannelIds);
  final channelMap = {for (final c in channels) c.id: c};

  return recentChannelIds
      .map((id) => channelMap[id])
      .whereType<Channel>()
      .toList();
});

/// Fetches the current profile's favorite channels.
final favoriteChannelsProvider = FutureProvider.autoDispose<List<Channel>>((
  ref,
) async {
  final profileState = ref.watch(profileServiceProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  final activeProfileId = profileState.asData?.value.activeProfileId;

  if (activeProfileId == null) return [];

  // 1. Get favorite channel IDs for this profile
  final favIds = await cacheService.getFavorites(activeProfileId);

  if (favIds.isEmpty) return [];

  // 2. Fetch Channel entities
  return cacheService.getChannelsByIds(favIds);
});

/// Fetches the 10 most recently added VOD items.
///
/// Items are sorted by [VodItem.addedAt] descending so the
/// newest additions appear first. Falls back to the first 10
/// items in load order when no [addedAt] timestamps exist.
final latestVodProvider = FutureProvider<List<VodItem>>((ref) async {
  final items = ref.watch(filteredVodProvider);
  final sorted = [...items]..sort((a, b) {
    final aAdded = a.addedAt;
    final bAdded = b.addedAt;
    if (aAdded == null && bAdded == null) return 0;
    if (aAdded == null) return 1;
    if (bAdded == null) return -1;
    return bAdded.compareTo(aAdded);
  });
  return sorted.take(10).toList();
});

/// Featured VOD items for the home hero banner.
///
/// Uses the paginated movies feed as the source of truth instead of the
/// legacy bulk-loaded [vodProvider] state.
final featuredVodProvider = FutureProvider<List<VodItem>>((ref) async {
  final items = ref.watch(filteredMoviesProvider);
  return featuredItems(items, limit: 5);
});

// ── Task 5C: top10Vod → backend.filterTopVod ─────────────

/// Async implementation backing [top10VodProvider].
///
/// Exposed for test settling — prefer [top10VodProvider] in UI code.
final top10VodAsyncProvider = FutureProvider<List<VodItem>>((ref) async {
  final items = ref.watch(filteredVodProvider);
  if (items.isEmpty) return const [];
  final cache = ref.read(cacheServiceProvider);
  return cache.filterTopVod(items, 10);
});

/// Top 10 items: highest-rated VOD items with poster art.
///
/// Sorted by rating descending, capped at 10. Falls back to
/// newest releases if no ratings are available.
///
/// Delegates to [backend.filterTopVod] via Rust FFI.
/// Returns the last known value while the async call is in flight.
final top10VodProvider = Provider<List<VodItem>>((ref) {
  return ref
      .watch(top10VodAsyncProvider)
      .maybeWhen(data: (items) => items, orElse: () => const []);
});

// ── Task 5E: resolveNextEpisodes → backend.resolveNextEpisodes ──

/// Continue-watching series list with next-episode substitution.
///
/// Wraps [continueWatchingSeriesProvider]: entries that are
/// >= 90% complete are replaced by their next episode so the
/// home screen row always surfaces the episode the user
/// should watch next.
///
/// Delegates to [backend.resolveNextEpisodes] via Rust FFI.
final continueWatchingSeriesNextEpisodeProvider =
    FutureProvider<List<WatchHistoryEntry>>((ref) async {
      final seriesEntries = await ref.watch(
        continueWatchingSeriesProvider.future,
      );
      if (seriesEntries.isEmpty) return const [];
      final cache = ref.read(cacheServiceProvider);
      final episodeItems =
          ref
              .watch(filteredVodProvider)
              .where((item) => item.type == VodType.episode)
              .toList();
      return cache.resolveNextEpisodes(
        seriesEntries,
        episodeItems,
        kNextEpisodeThreshold,
      );
    });

// ── Task 5D: filterUpcomingPrograms → backend.filterUpcomingPrograms ──

/// Async implementation backing [upcomingProgramsProvider].
///
/// The Rust backend returns a flat JSON array — each element contains
/// both the channel metadata (id, name, stream_url, logo_url) and the
/// EPG entry data (title, start_time ms, end_time ms, description?,
/// category?). This provider reconstructs [UpcomingProgram] objects
/// from those flat elements.
///
/// Exposed for test settling — prefer [upcomingProgramsProvider] in UI code.
final upcomingProgramsAsyncProvider = FutureProvider<List<UpcomingProgram>>((
  ref,
) async {
  final epgState = ref.watch(epgProvider);
  final favoritesAsync = ref.watch(favoriteChannelsProvider);

  if (epgState.entries.isEmpty) return const [];
  final favorites = favoritesAsync.asData?.value;
  if (favorites == null || favorites.isEmpty) return const [];

  final cache = ref.read(cacheServiceProvider);

  // Encode EPG entries in the epoch-ms format expected by Rust.
  final epgMapJson = EpgJsonCodec.encode(epgState.entries);

  final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

  // The Rust result is a flat array with channel + entry info embedded.
  // Each element has: channel_id, channel_name, stream_url, logo_url?,
  //   title, start_time (epoch ms), end_time (epoch ms),
  //   description?, category?
  final raw = await cache.filterUpcomingPrograms(
    epgMapJson: epgMapJson,
    favorites: favorites,
    nowMs: nowMs,
    windowMinutes: 120,
    limit: 20,
  );

  return raw.map((m) {
    final channel = Channel(
      id: m['channel_id'] as String,
      name: m['channel_name'] as String? ?? '',
      streamUrl: m['stream_url'] as String? ?? '',
      logoUrl: m['logo_url'] as String?,
    );
    final entry = EpgEntry(
      channelId: m['channel_id'] as String,
      title: m['title'] as String? ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (m['start_time'] as num).toInt(),
        isUtc: true,
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (m['end_time'] as num).toInt(),
        isUtc: true,
      ),
      description: m['description'] as String?,
      category: m['category'] as String?,
    );
    return UpcomingProgram(channel: channel, entry: entry);
  }).toList();
});

/// Upcoming programmes for favorite channels within the
/// next 120 minutes.
///
/// Queries EPG data for all favorite channels, collects
/// entries that start within the look-ahead window, sorts
/// by start time ascending, and caps the result at 20
/// entries.
///
/// Returns an empty list when:
/// - No favorite channels are loaded.
/// - EPG data is not loaded.
/// - No entries fall within the look-ahead window.
///
/// Delegates to [backend.filterUpcomingPrograms] via Rust FFI.
/// Returns the last known value while the async call is in flight.
final upcomingProgramsProvider = Provider<List<UpcomingProgram>>((ref) {
  return ref
      .watch(upcomingProgramsAsyncProvider)
      .maybeWhen(data: (items) => items, orElse: () => const []);
});
