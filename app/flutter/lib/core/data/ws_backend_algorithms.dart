part of 'ws_backend.dart';

/// Recommendation, search, watch-progress, and utility algorithm commands.
mixin _WsAlgorithmsMixin on _WsBackendBase {
  // ── Recommendations ────────────────────────────

  Future<String> computeRecommendations({
    required String vodItemsJson,
    required String channelsJson,
    required String historyJson,
    required List<String> favoriteChannelIds,
    required List<String> favoriteVodIds,
    required int maxAllowedRating,
    required int nowUtcMs,
  }) async {
    final data = await _send('computeRecommendations', {
      'vodItemsJson': vodItemsJson,
      'channelsJson': channelsJson,
      'historyJson': historyJson,
      'favoriteChannelIds': favoriteChannelIds,
      'favoriteVodIds': favoriteVodIds,
      'maxAllowedRating': maxAllowedRating,
      'nowUtcMs': nowUtcMs,
    });
    return data as String;
  }

  Future<String> parseRecommendationSections(String sectionsJson) async {
    final data = await _send('parseRecommendationSections', {
      'sectionsJson': sectionsJson,
    });
    return data as String;
  }

  Future<String> deserializeRecommendationSections(String sectionsJson) async {
    final data = await _send('deserializeRecommendationSections', {
      'sectionsJson': sectionsJson,
    });
    return data as String;
  }

  // ── PIN ────────────────────────────────────────

  Future<String> hashPin(String pin) async {
    final data = await _send('hashPin', {'pin': pin});
    return data as String;
  }

  Future<bool> verifyPin(String inputPin, String storedHash) async {
    final data = await _send('verifyPin', {
      'inputPin': inputPin,
      'storedHash': storedHash,
    });
    return data as bool;
  }

  /// Delegates to shared [dartIsHashedPin].
  bool isHashedPin(String value) => dartIsHashedPin(value);

  // ── Search ─────────────────────────────────────

  Future<String> searchContent({
    required String query,
    required String channelsJson,
    required String vodItemsJson,
    required String epgEntriesJson,
    required String filterJson,
  }) async {
    final data = await _send('searchContent', {
      'query': query,
      'channelsJson': channelsJson,
      'vodItemsJson': vodItemsJson,
      'epgEntriesJson': epgEntriesJson,
      'filterJson': filterJson,
    });
    return data as String;
  }

  Future<String> enrichSearchResults(
    String query,
    String resultsJson,
    String channelsJson,
    String vodItemsJson,
  ) async {
    final data = await _send('enrichSearchResults', {
      'query': query,
      'resultsJson': resultsJson,
      'channelsJson': channelsJson,
      'vodItemsJson': vodItemsJson,
    });
    return data as String;
  }

  Future<String> groupSearchResults(
    String resultsJson,
    String channelsJson,
    String vodJson,
    String epgJson,
  ) async {
    final data = await _send('groupSearchResults', {
      'resultsJson': resultsJson,
      'channelsJson': channelsJson,
      'vodJson': vodJson,
      'epgJson': epgJson,
    });
    return data as String;
  }

  // ── Watch Thresholds ─────────────────────────

  /// Sync fallback — returns canonical value (WS cannot call FFI sync).
  double completionThreshold() => kCompletionThreshold;

  /// Sync fallback — returns canonical value (WS cannot call FFI sync).
  double nextEpisodeThreshold() => kNextEpisodeThreshold;

  // ── Watch Progress ───────────────────────────

  /// Sync — delegates to shared [dartCalculateWatchProgress].
  double calculateWatchProgress(int positionMs, int durationMs) =>
      dartCalculateWatchProgress(positionMs, durationMs);

  Future<String> filterContinueWatchingPositions(String json, int limit) async {
    final data = await _send('filterContinueWatchingPositions', {
      'json': json,
      'limit': limit,
    });
    return data as String;
  }

  // ── Playback Duration Formatting ──────────────

  /// Sync — delegates to shared [dartFormatPlaybackDuration].
  String formatPlaybackDuration(int positionMs, int durationMs) =>
      dartFormatPlaybackDuration(positionMs, durationMs);

  // ── Group Icon ──────────────────────────────

  /// Sync — delegates to shared [dartMatchGroupIcon].
  String matchGroupIcon(String groupName) => dartMatchGroupIcon(groupName);

  // ── URL Normalization ─────────────────────────

  /// Sync — delegates to shared [dartNormalizeApiBaseUrl].
  String normalizeApiBaseUrl(String url) => dartNormalizeApiBaseUrl(url);

  // ── Config Merge ──────────────────────────────

  /// Sync — delegates to shared [dartDeepMergeJson].
  String deepMergeJson(String baseJson, String overridesJson) =>
      dartDeepMergeJson(baseJson, overridesJson);

  /// Sync — delegates to shared [dartSetNestedValue].
  String setNestedValue(String mapJson, String dotPath, String valueJson) =>
      dartSetNestedValue(mapJson, dotPath, valueJson);

  // ── Permission ────────────────────────────────

  /// Sync — delegates to shared [dartCanViewRecording].
  bool canViewRecording(
    String role,
    String recordingOwnerId,
    String currentProfileId,
  ) => dartCanViewRecording(role, recordingOwnerId, currentProfileId);

  /// Sync — delegates to shared [dartCanDeleteRecording].
  bool canDeleteRecording(
    String role,
    String recordingOwnerId,
    String currentProfileId,
  ) => dartCanDeleteRecording(role, recordingOwnerId, currentProfileId);

  // ── Channel Sorting ───────────────────────────

  Future<String> filterAndSortChannels(
    String channelsJson,
    String paramsJson,
  ) async {
    final data = await _send('filterAndSortChannels', {
      'channelsJson': channelsJson,
      'paramsJson': paramsJson,
    });
    return data as String;
  }

  /// Sync — delegates to shared [dartSortFavorites].
  String sortFavorites(String channelsJson, String sortMode) =>
      dartSortFavorites(channelsJson, sortMode);

  // ── Category Sorting ──────────────────────────

  /// Sync — delegates to shared [dartSortCategoriesWithFavorites].
  String sortCategoriesWithFavorites(
    String categoriesJson,
    String favoritesJson,
  ) => dartSortCategoriesWithFavorites(categoriesJson, favoritesJson);

  Future<String> buildTypeCategories(String itemsJson, String vodType) async {
    final data = await _send('buildTypeCategories', {
      'itemsJson': itemsJson,
      'vodType': vodType,
    });
    return data as String;
  }

  // ── VOD Filtering ─────────────────────────────

  Future<String> filterRecentlyAdded(
    String itemsJson,
    int cutoffDays,
    int nowMs,
  ) async {
    final data = await _send('filterRecentlyAdded', {
      'itemsJson': itemsJson,
      'cutoffDays': cutoffDays,
      'nowMs': nowMs,
    });
    return data as String;
  }

  // ── Watch History ─────────────────────────────

  /// Sync — delegates to shared [dartComputeWatchStreak].
  int computeWatchStreak(String timestampsJson, int nowMs) =>
      dartComputeWatchStreak(timestampsJson, nowMs);

  Future<String> computeProfileStats(String historyJson, int nowMs) async {
    final data = await _send('computeProfileStats', {
      'historyJson': historyJson,
      'nowMs': nowMs,
    });
    return data as String;
  }

  Future<String> mergeDedupSortHistory(String aJson, String bJson) async {
    final data = await _send('mergeDedupSortHistory', {
      'aJson': aJson,
      'bJson': bJson,
    });
    return data as String;
  }

  Future<String> filterByCwStatus(String historyJson, String filter) async {
    final data = await _send('filterByCwStatus', {
      'historyJson': historyJson,
      'filter': filter,
    });
    return data as String;
  }

  Future<String> seriesIdsWithNewEpisodes(
    String seriesJson,
    int days,
    int nowMs,
  ) async {
    final data = await _send('seriesIdsWithNewEpisodes', {
      'seriesJson': seriesJson,
      'days': days,
      'nowMs': nowMs,
    });
    return data as String;
  }

  /// Sync — delegates to shared [dartCountInProgressEpisodes].
  int countInProgressEpisodes(String historyJson, String seriesId) =>
      dartCountInProgressEpisodes(historyJson, seriesId);

  // ── EPG: Upcoming Programs ──────────────────────

  Future<String> filterUpcomingPrograms(
    String epgMapJson,
    String favoritesJson,
    int nowMs,
    int windowMinutes,
    int limit,
  ) async {
    final data = await _send('filterUpcomingPrograms', {
      'epgMapJson': epgMapJson,
      'favoritesJson': favoritesJson,
      'nowMs': nowMs,
      'windowMinutes': windowMinutes,
      'limit': limit,
    });
    return data as String;
  }

  // ── Search (Advanced) ───────────────────────────

  Future<String> searchChannelsByLiveProgram(
    String epgMapJson,
    String query,
    int nowMs,
  ) async {
    final data = await _send('searchChannelsByLiveProgram', {
      'epgMapJson': epgMapJson,
      'query': query,
      'nowMs': nowMs,
    });
    return data as String;
  }

  Future<String> mergeEpgMatchedChannels(
    String baseJson,
    String allChannelsJson,
    String matchedIdsJson,
    String epgOverridesJson,
  ) async {
    final data = await _send('mergeEpgMatchedChannels', {
      'baseJson': baseJson,
      'allChannelsJson': allChannelsJson,
      'matchedIdsJson': matchedIdsJson,
      'epgOverridesJson': epgOverridesJson,
    });
    return data as String;
  }

  /// Sync — delegates to shared [dartBuildSearchCategories].
  String buildSearchCategories(
    String vodCategoriesJson,
    String channelGroupsJson,
  ) => dartBuildSearchCategories(vodCategoriesJson, channelGroupsJson);

  // ── Watch History (Advanced) ────────────────────

  Future<String> resolveNextEpisodes(
    String entriesJson,
    String vodItemsJson,
    double threshold,
  ) async {
    final data = await _send('resolveNextEpisodes', {
      'entriesJson': entriesJson,
      'vodItemsJson': vodItemsJson,
      'threshold': threshold,
    });
    return data as String;
  }

  /// Sync — delegates to shared [dartEpisodeCountBySeason].
  String episodeCountBySeason(String episodesJson) =>
      dartEpisodeCountBySeason(episodesJson);

  /// Sync — delegates to shared [dartVodBadgeKind].
  String vodBadgeKind(int? year, int? addedAtMs, int nowMs) =>
      dartVodBadgeKind(year, addedAtMs, nowMs);

  Future<String> similarVodItems(
    String itemsJson,
    String itemId,
    int limit,
  ) async {
    final data = await _send('similarVodItems', {
      'itemsJson': itemsJson,
      'itemId': itemId,
      'limit': limit,
    });
    return data as String;
  }

  // ── PIN Lockout ─────────────────────────────────

  /// Sync — delegates to shared [dartIsLockActive].
  bool isLockActive(int lockedUntilMs, int nowMs) =>
      dartIsLockActive(lockedUntilMs, nowMs);

  /// Sync — delegates to shared [dartLockRemainingMs].
  int lockRemainingMs(int lockedUntilMs, int nowMs) =>
      dartLockRemainingMs(lockedUntilMs, nowMs);

  // ── Watch History ID ─────────────────────────────

  /// Sync — delegates to shared [dartDeriveWatchHistoryId].
  ///
  /// WS sync methods cannot issue async WebSocket calls, so this
  /// uses the pure-Dart SHA-256 fallback which produces identical
  /// output to the Rust `derive_watch_history_id` function.
  String deriveWatchHistoryId(String url) => dartDeriveWatchHistoryId(url);

  // ── VOD Quality ───────────────────────────────────────

  /// Sync — delegates to shared [dartResolveVodQuality].
  String? resolveVodQuality(String? extension, String streamUrl) =>
      dartResolveVodQuality(extension, streamUrl);

  // ── Server URL Normalization ──────────────────────────

  /// Sync — delegates to shared [dartNormalizeServerUrl].
  String normalizeServerUrl(String raw) => dartNormalizeServerUrl(raw);
}
