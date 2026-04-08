import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../dvr/domain/utils/dvr_payload.dart';
import 'vod_service_providers.dart';
import '../../domain/entities/vod_item.dart';
import '../../domain/utils/vod_utils.dart';
import '../widgets/series_episode_fetcher.dart';
import '../widgets/vod_source_picker.dart';
import 'vod_derived_providers.dart';
import 'vod_providers.dart';

// ══════════════════════════════════════════════════════════════════
//  New Episodes Detection (FE-Series-03)
// ══════════════════════════════════════════════════════════════════

/// Number of days a series update is considered "new" for badge display.
const kNewEpisodesDays = 14;

/// Async backend call for series with new episodes.
final _seriesWithNewEpisodesAsyncProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final series = ref.watch(filteredSeriesProvider);
      if (series.isEmpty) return {};
      final repo = ref.read(vodRepositoryProvider);
      return repo.seriesIdsWithNewEpisodes(
        series,
        kNewEpisodesDays,
        DateTime.now().millisecondsSinceEpoch,
      );
    });

/// Returns the set of series item IDs that have been updated within
/// the last [kNewEpisodesDays] days.
///
/// Heuristic: if [VodItem.updatedAt] is more recent than the cutoff, the
/// series likely has new episodes since the playlist was last synced.
///
/// The set rebuilds only when the series list changes.
final seriesWithNewEpisodesProvider = Provider.autoDispose<Set<String>>((ref) {
  return ref.watch(_seriesWithNewEpisodesAsyncProvider).value ?? {};
});

/// Same-category recommendations for a given VOD item.
///
/// Returns up to 10 movies sharing the same [VodItem.category],
/// excluding the item itself. Uses `.select()` to only rebuild
/// when the movies list changes.
final vodSimilarItemsProvider = Provider.family
    .autoDispose<List<VodItem>, String>((ref, itemId) {
      final movies = ref.watch(vodProvider.select((s) => s.movies));
      final current = movies.where((m) => m.id == itemId).firstOrNull;
      if (current == null || current.category == null) return [];
      return movies
          .where((m) => m.category == current.category && m.id != itemId)
          .take(10)
          .toList();
    });

// ══════════════════════════════════════════════════════════════════
//  Series Episodes Provider
// ══════════════════════════════════════════════════════════════════

/// Key used to identify a series episode fetch request.
///
/// Combines [seriesId] and optional [sourceId] so the provider
/// correctly caches per (series, source) pair.
typedef SeriesEpisodesKey = ({String seriesId, String? sourceId});

/// Fetches and caches episode data for a series.
///
/// autoDispose: kept alive while [SeriesDetailScreen] is mounted
/// and freed when the user pops back — no manual invalidation
/// required, no re-fetch on re-push within the same navigation
/// stack entry.
///
/// Keyed by [SeriesEpisodesKey] so different sources for the
/// same series ID don't share the same cache slot.
final seriesEpisodesProvider = FutureProvider.family
    .autoDispose<EpisodeFetchResult, SeriesEpisodesKey>((ref, key) async {
      return fetchSeriesEpisodes(ref, key.seriesId, sourceId: key.sourceId);
    });

// ══════════════════════════════════════════════════════════════════
//  Unwatched Episode Count (FE-Series-02)
// ══════════════════════════════════════════════════════════════════

/// Returns the count of episodes for a series that have been started
/// but not yet completed (progress > 0 and < [kCompletionThreshold]).
///
/// This gives the user an actionable "episodes to finish" count
/// without requiring a full episode-list API call per series.
/// The count is derived entirely from local watch history.
///
/// Returns 0 when no in-progress episodes exist.
final seriesUnwatchedCountProvider = FutureProvider.family
    .autoDispose<int, String>((ref, seriesId) async {
      final service = ref.watch(watchHistoryServiceProvider);
      final all = await service.getAll();
      return countInProgressEpisodesForSeries(
        all
            .map(
              (e) => (
                seriesId: e.seriesId,
                mediaType: e.mediaType,
                durationMs: e.durationMs,
                isNearlyComplete: e.isNearlyComplete,
              ),
            )
            .toList(),
        seriesId,
      );
    });

// ══════════════════════════════════════════════════════════════════
//  VOD Alternative Sources (FE-VODS-06-ALT)
// ══════════════════════════════════════════════════════════════════

/// Alternative sources for a VOD item (same title from different sources).
///
/// Returns [VodSource] objects for the VodSourcePicker widget.
/// Includes any alternatives beyond the primary item; callers should
/// prepend the item itself as the first source.
/// Returns an empty list when no cross-source duplicates are found.
final vodAlternativeSourcesProvider = FutureProvider.family
    .autoDispose<List<VodSource>, VodItem>((ref, item) async {
      final repo = ref.read(vodRepositoryProvider);
      final altMaps = await repo.findVodAlternatives(
        item.name,
        item.year ?? 0,
        item.id,
        10,
      );
      if (altMaps.isEmpty) return [];
      // Resolve source names from settings.
      final settings = ref.read(settingsNotifierProvider).value;
      final sourceMap = <String, String>{};
      if (settings != null) {
        for (final s in settings.sources) {
          sourceMap[s.id] = s.name;
        }
      }
      return altMaps.map((m) {
        final sourceId = m['source_id'] as String?;
        final sourceName = sourceId != null ? sourceMap[sourceId] : null;
        final label =
            sourceName ?? (sourceId != null ? 'Server $sourceId' : 'Default');
        final quality = dartResolveVodQuality(
          m['extension_'] as String?,
          m['stream_url'] as String? ?? '',
        );
        return VodSource(
          label: label,
          streamUrl: m['stream_url'] as String? ?? '',
          quality: quality,
        );
      }).toList();
    });

// ══════════════════════════════════════════════════════════════════
//  On-Demand VOD Metadata Fetch
// ══════════════════════════════════════════════════════════════════

/// Lazily fetches full VOD metadata from the Xtream
/// `get_vod_info` endpoint when the detail pane opens.
///
/// The bulk `get_vod_streams` only returns basic info
/// (name, poster, rating). Full metadata (plot, cast,
/// director, genre, duration, backdrop, tmdb_id) is
/// only available per-item from `get_vod_info`.
///
/// Keyed by the VOD item so the fetch is deduplicated
/// across the TV detail pane and full detail screen.
///
/// autoDispose: freed when the detail view unmounts,
/// re-fetched on next open if cache was invalidated.
final vodDetailProvider = FutureProvider.family.autoDispose<VodItem?, VodItem>((
  ref,
  item,
) async {
  return fetchVodDetail(ref, item);
});
