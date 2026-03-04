import 'dart:convert';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../../iptv/domain/entities/channel.dart';
import '../../vod/domain/entities/vod_item.dart';
import '../domain/entities/recommendation.dart';

/// Lightweight watch-history record for isolate
/// transfer.
class WatchSignal {
  const WatchSignal({
    required this.id,
    required this.mediaType,
    required this.positionMs,
    required this.durationMs,
    required this.lastWatched,
  });

  /// Item ID (channel or VOD).
  final String id;

  /// Content type: 'channel', 'movie', 'episode'.
  final String mediaType;

  /// Playback position in milliseconds.
  final int positionMs;

  /// Total duration in milliseconds.
  final int durationMs;

  /// When the item was last watched.
  final DateTime lastWatched;

  /// Serialize to JSON map for backend transfer.
  Map<String, dynamic> toJson() => {
    'item_id': id,
    'media_type': mediaType,
    'watched_percent':
        durationMs > 0 ? positionMs.toDouble() / durationMs.toDouble() : 0.0,
    'last_watched_ms': lastWatched.millisecondsSinceEpoch,
  };
}

/// Aggregated user signals for recommendation
/// scoring.
class UserSignals {
  const UserSignals({
    required this.history,
    required this.favoriteChannelIds,
    required this.favoriteVodIds,
  });

  /// Watch history entries (most recent first).
  final List<WatchSignal> history;

  /// IDs of user-favorited channels.
  final Set<String> favoriteChannelIds;

  /// IDs of user-favorited VOD items.
  final Set<String> favoriteVodIds;
}

/// On-device recommendation engine that delegates
/// scoring to the Rust backend via [CrispyBackend].
class RecommendationEngine {
  RecommendationEngine(this._cache, this._backend);

  final CacheService _cache;
  final CrispyBackend _backend;

  /// Load user signals from the cache/backend.
  Future<UserSignals> loadSignals({required String profileId}) async {
    final rawHistory = await _cache.loadWatchHistory();
    // Sort by lastWatched descending.
    rawHistory.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));

    final favoriteChannelIds = (await _cache.getFavorites(profileId)).toSet();
    final favoriteVodIds = (await _cache.getVodFavorites(profileId)).toSet();

    return UserSignals(
      history:
          rawHistory
              .map(
                (h) => WatchSignal(
                  id: h.id,
                  mediaType: h.mediaType,
                  positionMs: h.positionMs,
                  durationMs: h.durationMs,
                  lastWatched: h.lastWatched,
                ),
              )
              .toList(),
      favoriteChannelIds: favoriteChannelIds,
      favoriteVodIds: favoriteVodIds,
    );
  }

  /// Generate all recommendation sections.
  ///
  /// Loads signals from cache, serializes all input
  /// data, delegates computation to the Rust backend,
  /// and deserializes the result.
  Future<List<RecommendationSection>> generateAll({
    required String profileId,
    required int maxAllowedRating,
    required List<VodItem> allVodItems,
    required List<Channel> allChannels,
  }) async {
    final signals = await loadSignals(profileId: profileId);

    // Serialize inputs for the Rust backend.
    final vodItemsJson = jsonEncode(allVodItems.map(vodItemToMap).toList());
    final channelsJson = jsonEncode(allChannels.map(channelToMap).toList());
    final historyJson = jsonEncode(
      signals.history.map((h) => h.toJson()).toList(),
    );

    // Call Rust backend.
    final resultJson = await _backend.computeRecommendations(
      vodItemsJson: vodItemsJson,
      channelsJson: channelsJson,
      historyJson: historyJson,
      favoriteChannelIds: signals.favoriteChannelIds.toList(),
      favoriteVodIds: signals.favoriteVodIds.toList(),
      maxAllowedRating: maxAllowedRating,
      nowUtcMs: DateTime.now().millisecondsSinceEpoch,
    );

    // Single-pass deserialization in Rust: parses
    // section/reason types and merges all item fields.
    final fullJson = await _backend.deserializeRecommendationSections(
      resultJson,
    );
    return _fromFullJson(fullJson);
  }

  /// Map a camelCase section type string from the
  /// Rust backend to the Dart enum.
  static RecommendationReasonType _mapSectionType(String value) {
    switch (value) {
      case 'topPicks':
        return RecommendationReasonType.topPick;
      case 'becauseYouWatched':
        return RecommendationReasonType.becauseYouWatched;
      case 'popularInGenre':
        return RecommendationReasonType.popularInGenre;
      case 'trending':
        return RecommendationReasonType.trending;
      case 'newForYou':
        return RecommendationReasonType.newForYou;
      default:
        return RecommendationReasonType.coldStart;
    }
  }

  /// Build [RecommendationSection] list from the
  /// fully-merged JSON returned by the Rust backend.
  static List<RecommendationSection> _fromFullJson(String fullJson) {
    final sections =
        (jsonDecode(fullJson) as List<dynamic>).cast<Map<String, dynamic>>();

    return sections.map((s) {
      final sectionType = _mapSectionType(s['section_type'] as String? ?? '');
      final items =
          (s['items'] as List<dynamic>).cast<Map<String, dynamic>>().map((m) {
            final reasonType = _mapSectionType(
              m['reason_type'] as String? ?? '',
            );
            return Recommendation(
              itemId: m['id'] as String,
              itemName: m['name'] as String,
              mediaType: m['media_type'] as String,
              reason: RecommendationReason(
                type: reasonType,
                sourceItemName: m['source_title'] as String?,
                genreName: m['genre'] as String?,
              ),
              score: (m['score'] as num).toDouble(),
              posterUrl: m['poster_url'] as String?,
              category: m['category'] as String?,
              streamUrl: m['stream_url'] as String?,
              rating: m['rating'] as String?,
              year: m['year'] as int?,
              seriesId: m['series_id'] as String?,
            );
          }).toList();

      // Build a dynamic "Because you watched [Title]" label when
      // the backend provides a source_title for the section.
      final sourceTitle = s['source_title'] as String?;
      final dynamicTitle =
          sectionType == RecommendationReasonType.becauseYouWatched &&
                  sourceTitle != null &&
                  sourceTitle.isNotEmpty
              ? 'Because you watched $sourceTitle'
              : null;

      return RecommendationSection(
        title: s['title'] as String,
        dynamicTitle: dynamicTitle,
        reasonType: sectionType,
        items: items,
      );
    }).toList();
  }
}
