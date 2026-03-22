part of 'ffi_backend.dart';

/// Parser and algorithm bridge FFI calls.
mixin _FfiParsersMixin on _FfiBackendBase {
  // ── Parsers ──────────────────────────────────────

  Future<Map<String, dynamic>> parseM3u(String content) async {
    final json = await rust_api.parseM3U(content: content);
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('FFI JSON decode error in parseM3u: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> parseVodStreams(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
    String? sourceId,
  }) async {
    final result = await rust_api.parseVodStreams(
      json: json,
      baseUrl: baseUrl,
      username: username,
      password: password,
      sourceId: sourceId,
    );
    try {
      final decodedList = jsonDecode(result) as List;
      return decodedList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('FfiBackend: ERROR decoding parseVodStreams result: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> parseSeries(
    String json, {
    String? sourceId,
  }) async {
    final result = await rust_api.parseSeries(json: json, sourceId: sourceId);
    try {
      return (jsonDecode(result) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('FFI JSON decode error in parseSeries: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> parseEpisodes(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
    required String seriesId,
  }) async {
    final result = await rust_api.parseEpisodes(
      json: json,
      baseUrl: baseUrl,
      username: username,
      password: password,
      seriesId: seriesId,
    );
    try {
      return (jsonDecode(result) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('FFI JSON decode error in parseEpisodes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> parseM3uVod(
    String json, {
    String? sourceId,
  }) async {
    final result = await rust_api.parseM3UVod(json: json, sourceId: sourceId);
    try {
      return (jsonDecode(result) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('FFI JSON decode error in parseM3uVod: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> parseVttThumbnails(
    String content,
    String baseUrl,
  ) async {
    final json = await rust_api.parseVttThumbnails(
      content: content,
      baseUrl: baseUrl,
    );
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('FFI JSON decode error in parseVttThumbnails: $e');
      return null;
    }
  }

  Future<String> parseBifIndex(List<int> data) =>
      rust_api.parseBifIndex(data: data);

  // ── Utility Algorithms ─────────────────────────

  String tryBase64Decode(String input) =>
      rust_api.tryBase64Decode(input: input);

  // ── Stalker Parsers ────────────────────────────

  Future<String> parseStalkerVodItems(
    String json,
    String baseUrl, {
    String vodType = 'movie',
  }) => rust_api.parseStalkerVodItems(
    json: json,
    baseUrl: baseUrl,
    vodType: vodType,
  );

  Future<String> parseStalkerChannels(String json) =>
      rust_api.parseStalkerChannels(json: json);

  Future<String> parseStalkerLiveStreams(
    String json,
    String sourceId,
    String baseUrl,
  ) => rust_api.parseStalkerLiveStreams(
    json: json,
    sourceId: sourceId,
    baseUrl: baseUrl,
  );

  String buildStalkerStreamUrl(String cmd, String baseUrl) =>
      rust_api.buildStalkerStreamUrl(cmd: cmd, baseUrl: baseUrl);

  Future<String?> parseStalkerCreateLink(String json, String baseUrl) =>
      rust_api.parseStalkerCreateLink(json: json, baseUrl: baseUrl);

  Future<String> parseStalkerCategories(String json) =>
      rust_api.parseStalkerCategories(json: json);

  Future<String> parseStalkerVodResult(String json) =>
      rust_api.parseStalkerVodResult(json: json);

  // ── Xtream Parsers ─────────────────────────────

  Future<String> buildCategoryMap(String categoriesJson) =>
      rust_api.buildCategoryMap(categoriesJson: categoriesJson);

  Future<String> parseXtreamLiveStreams(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
  }) => rust_api.parseXtreamLiveStreams(
    json: json,
    baseUrl: baseUrl,
    username: username,
    password: password,
  );

  Future<String> parseXtreamCategories(String json) =>
      rust_api.parseXtreamCategories(json: json);

  // ── Recommendations + PIN ──────────────────────

  Future<String> computeRecommendations({
    required String vodItemsJson,
    required String channelsJson,
    required String historyJson,
    required List<String> favoriteChannelIds,
    required List<String> favoriteVodIds,
    required int maxAllowedRating,
    required int nowUtcMs,
  }) => rust_api.computeRecommendations(
    vodItemsJson: vodItemsJson,
    channelsJson: channelsJson,
    historyJson: historyJson,
    favoriteChannelIds: favoriteChannelIds,
    favoriteVodIds: favoriteVodIds,
    maxAllowedRating: maxAllowedRating,
    nowUtcMs: PlatformInt64Util.from(nowUtcMs),
  );

  Future<String> hashPin(String pin) async => rust_api.hashPin(pin: pin);

  Future<bool> verifyPin(String inputPin, String storedHash) async =>
      rust_api.verifyPin(inputPin: inputPin, storedHash: storedHash);

  bool isHashedPin(String value) => rust_api.isHashedPin(value: value);

  // ── Xtream URL Builders ────────────────────────

  String buildXtreamActionUrl({
    required String baseUrl,
    required String username,
    required String password,
    required String action,
    String? paramsJson,
  }) => rust_api.buildXtreamActionUrl(
    baseUrl: baseUrl,
    username: username,
    password: password,
    action: action,
    paramsJson: paramsJson,
  );

  String buildXtreamStreamUrl({
    required String baseUrl,
    required String username,
    required String password,
    required int streamId,
    required String streamType,
    required String extension,
  }) => rust_api.buildXtreamStreamUrl(
    baseUrl: baseUrl,
    username: username,
    password: password,
    streamId: PlatformInt64Util.from(streamId),
    streamType: streamType,
    extension_: extension,
  );

  String buildXtreamCatchupUrl({
    required String baseUrl,
    required String username,
    required String password,
    required int streamId,
    required int startUtc,
    required int durationMinutes,
  }) => rust_api.buildXtreamCatchupUrl(
    baseUrl: baseUrl,
    username: username,
    password: password,
    streamId: PlatformInt64Util.from(streamId),
    startUtc: PlatformInt64Util.from(startUtc),
    durationMinutes: durationMinutes,
  );

  // ── Search ─────────────────────────────────────

  Future<String> searchContent({
    required String query,
    required String channelsJson,
    required String vodItemsJson,
    required String epgEntriesJson,
    required String filterJson,
  }) => rust_api.searchContent(
    query: query,
    channelsJson: channelsJson,
    vodItemsJson: vodItemsJson,
    epgEntriesJson: epgEntriesJson,
    filterJson: filterJson,
  );

  Future<String> enrichSearchResults(
    String query,
    String resultsJson,
    String channelsJson,
    String vodItemsJson,
  ) => rust_api.enrichSearchResults(
    query: query,
    resultsJson: resultsJson,
    channelsJson: channelsJson,
    vodItemsJson: vodItemsJson,
  );

  // ── Watch Thresholds ─────────────────────────

  double completionThreshold() => rust_api.completionThreshold();

  double nextEpisodeThreshold() => rust_api.nextEpisodeThreshold();

  // ── Watch Progress ───────────────────────────

  double calculateWatchProgress(int positionMs, int durationMs) =>
      rust_api.calculateWatchProgress(
        positionMs: PlatformInt64Util.from(positionMs),
        durationMs: PlatformInt64Util.from(durationMs),
      );

  Future<String> filterContinueWatchingPositions(String json, int limit) =>
      rust_api.filterContinueWatchingPositions(
        json: json,
        limit: BigInt.from(limit),
      );

  // ── Playback Duration Formatting ──────────────

  String formatPlaybackDuration(int positionMs, int durationMs) =>
      rust_api.formatPlaybackDuration(
        positionMs: PlatformInt64Util.from(positionMs),
        durationMs: PlatformInt64Util.from(durationMs),
      );

  // ── Group Icon ──────────────────────────────

  String matchGroupIcon(String groupName) =>
      rust_api.matchGroupIcon(groupName: groupName);

  // ── Search Grouping ─────────────────────────

  Future<String> groupSearchResults(
    String resultsJson,
    String channelsJson,
    String vodJson,
    String epgJson,
  ) => rust_api.groupSearchResults(
    resultsJson: resultsJson,
    channelsJson: channelsJson,
    vodJson: vodJson,
    epgJson: epgJson,
  );

  // ── Recommendation Sections ────────────────────

  Future<String> parseRecommendationSections(String sectionsJson) =>
      rust_api.parseRecommendationSections(sectionsJson: sectionsJson);

  Future<String> deserializeRecommendationSections(String sectionsJson) =>
      rust_api.deserializeRecommendationSections(sectionsJson: sectionsJson);

  // ── VOD Sorting & Categorization ──────────────

  Future<String> sortVodItems(String itemsJson, String sortBy) =>
      rust_api.sortVodItems(itemsJson: itemsJson, sortBy: sortBy);

  Future<String> buildVodCategoryMap(String itemsJson) =>
      rust_api.buildVodCategoryMap(itemsJson: itemsJson);

  Future<String> filterTopVod(String itemsJson, int limit) =>
      rust_api.filterTopVod(itemsJson: itemsJson, limit: BigInt.from(limit));

  Future<String> computeEpisodeProgress(String historyJson, String seriesId) =>
      rust_api.computeEpisodeProgress(
        historyJson: historyJson,
        seriesId: seriesId,
      );

  Future<String> computeEpisodeProgressFromDb(String seriesId) =>
      rust_api.computeEpisodeProgressFromDb(seriesId: seriesId);

  Future<String> filterVodByContentRating(
    String itemsJson,
    int maxRatingValue,
  ) => rust_api.filterVodByContentRating(
    itemsJson: itemsJson,
    maxRatingValue: maxRatingValue,
  );

  // ── Channel Sorting ───────────────────────────

  Future<String> filterAndSortChannels(
    String channelsJson,
    String paramsJson,
  ) => rust_api.filterAndSortChannels(
    channelsJson: channelsJson,
    paramsJson: paramsJson,
  );

  String sortFavorites(String channelsJson, String sortMode) =>
      rust_api.sortFavorites(channelsJson: channelsJson, sortMode: sortMode);

  // ── Category Sorting ──────────────────────────

  String sortCategoriesWithFavorites(
    String categoriesJson,
    String favoritesJson,
  ) => rust_api.sortCategoriesWithFavorites(
    categoriesJson: categoriesJson,
    favoritesJson: favoritesJson,
  );

  Future<String> buildTypeCategories(String itemsJson, String vodType) =>
      rust_api.buildTypeCategories(itemsJson: itemsJson, vodType: vodType);

  // ── VOD Filtering ─────────────────────────────

  Future<String> filterRecentlyAdded(
    String itemsJson,
    int cutoffDays,
    int nowMs,
  ) => rust_api.filterRecentlyAdded(
    itemsJson: itemsJson,
    cutoffDays: cutoffDays,
    nowMs: PlatformInt64Util.from(nowMs),
  );

  // ── Watch History ─────────────────────────────

  int computeWatchStreak(String timestampsJson, int nowMs) =>
      rust_api.computeWatchStreak(
        timestampsJson: timestampsJson,
        nowMs: PlatformInt64Util.from(nowMs),
      );

  Future<String> computeProfileStats(String historyJson, int nowMs) =>
      rust_api.computeProfileStats(
        historyJson: historyJson,
        nowMs: PlatformInt64Util.from(nowMs),
      );

  Future<String> mergeDedupSortHistory(String aJson, String bJson) =>
      rust_api.mergeDedupSortHistory(aJson: aJson, bJson: bJson);

  Future<String> filterByCwStatus(String historyJson, String filter) =>
      rust_api.filterByCwStatus(historyJson: historyJson, filter: filter);

  Future<String> seriesIdsWithNewEpisodes(
    String seriesJson,
    int days,
    int nowMs,
  ) => rust_api.seriesIdsWithNewEpisodes(
    seriesJson: seriesJson,
    days: days,
    nowMs: PlatformInt64Util.from(nowMs),
  );

  int countInProgressEpisodes(String historyJson, String seriesId) =>
      rust_api
          .countInProgressEpisodes(historyJson: historyJson, seriesId: seriesId)
          .toInt();

  // ── URL Normalization ─────────────────────────

  String normalizeApiBaseUrl(String url) =>
      rust_api.normalizeApiBaseUrl(url: url);

  // ── Config Merge ──────────────────────────────

  String deepMergeJson(String baseJson, String overridesJson) =>
      rust_api.deepMergeJson(baseJson: baseJson, overridesJson: overridesJson);

  String setNestedValue(String mapJson, String dotPath, String valueJson) =>
      rust_api.setNestedValue(
        mapJson: mapJson,
        dotPath: dotPath,
        valueJson: valueJson,
      );

  // ── Permission ────────────────────────────────

  bool canViewRecording(
    String role,
    String recordingOwnerId,
    String currentProfileId,
  ) => rust_api.canViewRecording(
    role: role,
    recordingOwnerId: recordingOwnerId,
    currentProfileId: currentProfileId,
  );

  bool canDeleteRecording(
    String role,
    String recordingOwnerId,
    String currentProfileId,
  ) => rust_api.canDeleteRecording(
    role: role,
    recordingOwnerId: recordingOwnerId,
    currentProfileId: currentProfileId,
  );

  // ── Source Filter ─────────────────────────────

  Future<String> filterChannelsBySource(
    String channelsJson,
    String accessibleSourceIdsJson,
    bool isAdmin,
  ) => rust_api.filterChannelsBySource(
    channelsJson: channelsJson,
    accessibleSourceIdsJson: accessibleSourceIdsJson,
    isAdmin: isAdmin,
  );

  // ── Cloud Sync Direction ───────────────────────

  String determineSyncDirection(
    int localMs,
    int cloudMs,
    int lastSyncMs,
    String localDevice,
    String cloudDevice,
  ) => rust_api.determineSyncDirection(
    localMs: PlatformInt64Util.from(localMs),
    cloudMs: PlatformInt64Util.from(cloudMs),
    lastSyncMs: PlatformInt64Util.from(lastSyncMs),
    localDevice: localDevice,
    cloudDevice: cloudDevice,
  );

  // ── DVR: Recordings to Start ──────────────────

  Future<String> getRecordingsToStart(String recordingsJson, int nowMs) =>
      rust_api.getRecordingsToStart(
        recordingsJson: recordingsJson,
        nowMs: PlatformInt64Util.from(nowMs),
      );

  // ── EPG Window Merge ──────────────────────────

  Future<String> mergeEpgWindow(String existingJson, String newJson) =>
      rust_api.mergeEpgWindow(existingJson: existingJson, newJson: newJson);

  // ── EPG: Upcoming Programs ──────────────────────

  Future<String> filterUpcomingPrograms(
    String epgMapJson,
    String favoritesJson,
    int nowMs,
    int windowMinutes,
    int limit,
  ) => rust_api.filterUpcomingPrograms(
    epgMapJson: epgMapJson,
    favoritesJson: favoritesJson,
    nowMs: PlatformInt64Util.from(nowMs),
    windowMinutes: windowMinutes,
    limit: BigInt.from(limit),
  );

  // ── Search (Advanced) ───────────────────────────

  Future<String> searchChannelsByLiveProgram(
    String epgMapJson,
    String query,
    int nowMs,
  ) => rust_api.searchChannelsByLiveProgram(
    epgMapJson: epgMapJson,
    query: query,
    nowMs: PlatformInt64Util.from(nowMs),
  );

  Future<String> mergeEpgMatchedChannels(
    String baseJson,
    String allChannelsJson,
    String matchedIdsJson,
    String epgOverridesJson,
  ) => rust_api.mergeEpgMatchedChannels(
    baseJson: baseJson,
    allChannelsJson: allChannelsJson,
    matchedIdsJson: matchedIdsJson,
    epgOverridesJson: epgOverridesJson,
  );

  String buildSearchCategories(
    String vodCategoriesJson,
    String channelGroupsJson,
  ) => rust_api.buildSearchCategories(
    vodCategoriesJson: vodCategoriesJson,
    channelGroupsJson: channelGroupsJson,
  );

  // ── DVR (Advanced) ──────────────────────────────

  Future<String> computeStorageBreakdown(String recordingsJson, int nowMs) =>
      rust_api.computeStorageBreakdown(
        recordingsJson: recordingsJson,
        nowMs: PlatformInt64Util.from(nowMs),
      );

  Future<String> filterDvrRecordings(String recordingsJson, String query) =>
      rust_api.filterDvrRecordings(
        recordingsJson: recordingsJson,
        query: query,
      );

  String classifyFileType(String filename) =>
      rust_api.classifyFileType(filename: filename);

  Future<String> sortRemoteFiles(String filesJson, String order) =>
      rust_api.sortRemoteFiles(filesJson: filesJson, order: order);

  // ── Watch History (Advanced) ────────────────────

  Future<String> resolveNextEpisodes(
    String entriesJson,
    String vodItemsJson,
    double threshold,
  ) => rust_api.resolveNextEpisodes(
    entriesJson: entriesJson,
    vodItemsJson: vodItemsJson,
    threshold: threshold,
  );

  String episodeCountBySeason(String episodesJson) =>
      rust_api.episodeCountBySeason(episodesJson: episodesJson);

  String vodBadgeKind(int? year, int? addedAtMs, int nowMs) =>
      rust_api.vodBadgeKind(
        year: year,
        addedAtMs: addedAtMs != null ? PlatformInt64Util.from(addedAtMs) : null,
        nowMs: PlatformInt64Util.from(nowMs),
      );

  Future<String> similarVodItems(String itemsJson, String itemId, int limit) =>
      rust_api.similarVodItems(
        itemsJson: itemsJson,
        itemId: itemId,
        limit: BigInt.from(limit),
      );

  // ── PIN Lockout ─────────────────────────────────

  bool isLockActive(int lockedUntilMs, int nowMs) => rust_api.isLockActive(
    lockedUntilMs: PlatformInt64Util.from(lockedUntilMs),
    nowMs: PlatformInt64Util.from(nowMs),
  );

  int lockRemainingMs(int lockedUntilMs, int nowMs) =>
      rust_api
          .lockRemainingMs(
            lockedUntilMs: PlatformInt64Util.from(lockedUntilMs),
            nowMs: PlatformInt64Util.from(nowMs),
          )
          .toInt();

  // ── Watch History ID ─────────────────────────────

  /// Delegates to the sync Rust FFI function.
  String deriveWatchHistoryId(String url) =>
      rust_api.deriveWatchHistoryId(url: url);

  // ── VOD Quality ───────────────────────────────────────

  String? resolveVodQuality(String? extension, String streamUrl) =>
      rust_api.resolveVodQuality(extension_: extension, streamUrl: streamUrl);

  // ── Server URL Normalization ──────────────────────────

  String normalizeServerUrl(String raw) =>
      rust_api.normalizeServerUrl(raw: raw);
}
