part of 'ffi_backend.dart';

/// Parser and algorithm bridge FFI calls.
mixin _FfiParsersMixin on _FfiBackendBase {
  // ── Parsers ──────────────────────────────────────

  Future<Map<String, dynamic>> parseM3u(String content) async {
    final json = await rust_api.parseM3U(content: content);
    return jsonDecode(json) as Map<String, dynamic>;
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
    return (jsonDecode(result) as List).cast<Map<String, dynamic>>();
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
    return (jsonDecode(result) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> parseM3uVod(
    String json, {
    String? sourceId,
  }) async {
    final result = await rust_api.parseM3UVod(json: json, sourceId: sourceId);
    return (jsonDecode(result) as List).cast<Map<String, dynamic>>();
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
    return jsonDecode(json) as Map<String, dynamic>;
  }

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
    String resultsJson,
    String channelsJson,
    String vodItemsJson,
  ) => rust_api.enrichSearchResults(
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
}
