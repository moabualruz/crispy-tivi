import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/cache_service.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/domain/entities/watch_history_entry.dart';
import '../../../profiles/data/profile_service.dart';
import 'package:crispy_tivi/features/home/domain/utils/upcoming_programs.dart';
import 'package:crispy_tivi/features/vod/domain/utils/vod_utils.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';

export 'package:crispy_tivi/features/home/domain/utils/upcoming_programs.dart'
    show UpcomingProgram;

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
  return await cacheService.getChannelsByIds(favIds);
});

/// Fetches the 10 most recently added VOD items.
///
/// Items are sorted by [VodItem.addedAt] descending so the
/// newest additions appear first. Falls back to the first 10
/// items in load order when no [addedAt] timestamps exist.
final latestVodProvider = Provider<List<VodItem>>((ref) {
  final vodState = ref.watch(vodProvider);
  final items = vodState.items;
  if (items.isEmpty) return const [];

  // Sort by addedAt descending if timestamps are available.
  final withDate =
      items.where((i) => i.addedAt != null).toList()
        ..sort((a, b) => b.addedAt!.compareTo(a.addedAt!));

  if (withDate.isNotEmpty) {
    return withDate.take(10).toList();
  }

  // Fallback: take first 10 from the playlist order (newest imports
  // are typically appended at the end by the sync service).
  return items.reversed.take(10).toList();
});

/// Top 10 items: highest-rated VOD items with poster art.
///
/// Sorted by rating descending, capped at 10. Falls back to
/// newest releases if no ratings are available.
final top10VodProvider = Provider<List<VodItem>>((ref) {
  final vodState = ref.watch(vodProvider);
  return top10Vod(vodState.items, vodState.newReleases);
});

// ── Next-episode auto-queue threshold ───────────────────
//
// When an episode's progress meets or exceeds this value,
// the Continue Watching row shows the NEXT episode instead
// of the nearly-completed one. Set lower than
// [kCompletionThreshold] (0.95) so the card switches before
// the backend removes the entry from the continue-watching
// list.
const double _kNextEpisodeThreshold = 0.90;

/// Resolves the next unplayed episode for series entries that
/// are >= 90% complete.
///
/// For each entry in [entries]:
/// - Progress < 90% → kept as-is.
/// - Progress >= 90% → look up the series' episode list in
///   [vodProvider] and substitute the next sequential episode
///   (next by episode number within the same or next season).
/// - If no next episode is found (series complete), the
///   original entry is kept.
///
/// The returned list preserves the original sort order.
List<WatchHistoryEntry> resolveNextEpisodes(
  List<WatchHistoryEntry> entries,
  List<VodItem> allVodItems,
) {
  return entries.map((entry) {
    if (entry.mediaType != 'episode') return entry;
    if (entry.durationMs <= 0) return entry;
    final progress = entry.positionMs / entry.durationMs;
    if (progress < _kNextEpisodeThreshold) return entry;

    final seriesId = entry.seriesId;
    final season = entry.seasonNumber;
    final episode = entry.episodeNumber;
    if (seriesId == null || season == null || episode == null) return entry;

    // Gather all episodes for this series, sorted by season then episode.
    final seriesEpisodes =
        allVodItems
            .where(
              (v) =>
                  v.type == VodType.episode &&
                  v.seriesId == seriesId &&
                  v.seasonNumber != null &&
                  v.episodeNumber != null,
            )
            .toList()
          ..sort((a, b) {
            final sc = a.seasonNumber!.compareTo(b.seasonNumber!);
            return sc != 0 ? sc : a.episodeNumber!.compareTo(b.episodeNumber!);
          });

    if (seriesEpisodes.isEmpty) return entry;

    // Find the current episode index and advance by one.
    final currentIdx = seriesEpisodes.indexWhere(
      (v) => v.seasonNumber == season && v.episodeNumber == episode,
    );
    if (currentIdx == -1 || currentIdx + 1 >= seriesEpisodes.length) {
      // No next episode — series complete; keep original.
      return entry;
    }

    final next = seriesEpisodes[currentIdx + 1];

    // Return a new entry describing the next episode so the
    // Continue Watching card shows the upcoming episode's
    // metadata (title, thumbnail, episode numbers).
    return WatchHistoryEntry(
      id: next.id,
      mediaType: 'episode',
      name: next.name,
      streamUrl: next.streamUrl,
      posterUrl: next.posterUrl ?? entry.posterUrl,
      seriesPosterUrl: entry.seriesPosterUrl,
      positionMs: 0,
      durationMs: 0,
      lastWatched: entry.lastWatched,
      seriesId: next.seriesId,
      seasonNumber: next.seasonNumber,
      episodeNumber: next.episodeNumber,
      deviceId: entry.deviceId,
      deviceName: entry.deviceName,
      profileId: entry.profileId,
    );
  }).toList();
}

/// Continue-watching series list with next-episode substitution.
///
/// Wraps [continueWatchingSeriesProvider]: entries that are
/// >= 90% complete are replaced by their next episode so the
/// home screen row always surfaces the episode the user
/// should watch next.
final continueWatchingSeriesNextEpisodeProvider =
    FutureProvider<List<WatchHistoryEntry>>((ref) async {
      final seriesEntries = await ref.watch(
        continueWatchingSeriesProvider.future,
      );
      final vodState = ref.watch(vodProvider);
      return resolveNextEpisodes(seriesEntries, vodState.items);
    });

// ── Upcoming Programs (FE-H-07) ──────────────────────────

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
final upcomingProgramsProvider = Provider<List<UpcomingProgram>>((ref) {
  final epgState = ref.watch(epgProvider);
  final favoritesAsync = ref.watch(favoriteChannelsProvider);

  if (epgState.entries.isEmpty) return const [];
  final favorites = favoritesAsync.asData?.value;
  if (favorites == null || favorites.isEmpty) return const [];

  return filterUpcomingPrograms(epgState.entriesForChannel, favorites);
});
