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
    String resultsJson,
    String channelsJson,
    String vodItemsJson,
  ) async {
    final data = await _send('enrichSearchResults', {
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
}
