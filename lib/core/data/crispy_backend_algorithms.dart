part of 'crispy_backend.dart';

/// Algorithm methods: normalization, dedup, EPG matching,
/// catch-up URLs, DVR, S3 crypto, watch history filters,
/// Xtream URL builders, PIN hashing, recommendations,
/// sorting, category resolution, search, and timezone.
///
/// Implemented by [CrispyBackend] via `implements`.
abstract class _BackendAlgorithmMethods {
  // ── Normalization ────────────────────────────────────

  /// Normalize a channel name for matching.
  String normalizeChannelName(String name);

  /// Normalize a stream URL for comparison.
  String normalizeStreamUrl(String url);

  /// Try to base64-decode a string.
  /// Returns decoded or original if not valid base64.
  String tryBase64Decode(String input);

  // ── Dedup ────────────────────────────────────────────

  /// Detect duplicate channels by normalized URL.
  /// Input: JSON array of channel maps.
  /// Returns list of duplicate group maps.
  Future<List<Map<String, dynamic>>> detectDuplicateChannels(
    String channelsJson,
  );

  /// Find the duplicate group containing a channel.
  /// Returns JSON of DuplicateGroup or null.
  Future<String?> findGroupForChannel(String groupsJson, String channelId);

  /// Check if a channel ID is a duplicate.
  bool isDuplicate(String groupsJson, String channelId);

  /// Get all duplicate IDs across all groups.
  Future<List<String>> getAllDuplicateIds(String groupsJson);

  // ── EPG Matching ─────────────────────────────────────

  /// Match EPG entries to channels using 6 strategies.
  /// Returns {matched: {channelId: [entries]},
  ///          stats: {...}}.
  Future<Map<String, dynamic>> matchEpgToChannels({
    required String entriesJson,
    required String channelsJson,
    required String displayNamesJson,
  });

  /// Build a catch-up URL for a channel + EPG entry.
  /// Returns archive URL or null.
  Future<String?> buildCatchupUrl({
    required String channelJson,
    required int startUtc,
    required int endUtc,
  });

  // ── DVR Algorithms ───────────────────────────────────

  /// Expand recurring recordings into concrete
  /// instances for the next 7 days.
  /// Returns JSON array of RecordingInstance.
  Future<String> expandRecurringRecordings(String recordingsJson, int nowUtcMs);

  /// Check if a candidate recording conflicts with
  /// existing recordings on the same channel.
  Future<bool> detectRecordingConflict(
    String recordingsJson, {
    String? excludeId,
    required String channelName,
    required int startUtcMs,
    required int endUtcMs,
  });

  /// Sanitize a string for use as a filename.
  String sanitizeFilename(String name);

  // ── S3 Crypto ────────────────────────────────────────

  /// Sign an S3 request using AWS Signature V4.
  /// Returns JSON map of headers to add.
  Future<String> signS3Request({
    required String method,
    required String path,
    required int nowUtcMs,
    required String host,
    required String region,
    required String accessKey,
    required String secretKey,
    String? extraHeadersJson,
  });

  /// Generate a pre-signed URL for an S3 GET request.
  /// Returns the full URL string.
  Future<String> generatePresignedUrl({
    required String endpoint,
    required String bucket,
    required String objectKey,
    required String region,
    required String accessKey,
    required String secretKey,
    required int expirySecs,
    required int nowUtcMs,
  });

  // ── Watch History Algorithms ─────────────────────────

  /// Filter watch history for "continue watching".
  /// Returns JSON array of WatchHistory items.
  Future<String> filterContinueWatching(
    String historyJson, {
    String? mediaType,
    String? profileId,
  });

  /// Filter watch history for cross-device items.
  /// Returns JSON array of WatchHistory items.
  Future<String> filterCrossDevice(
    String historyJson,
    String currentDeviceId,
    int cutoffUtcMs,
  );

  // ── Xtream URL Builders ──────────────────────────────

  /// Build a category ID-to-name map from raw JSON.
  /// Returns JSON object {id: name}.
  Future<String> buildCategoryMap(String categoriesJson);

  /// Build an Xtream API action URL.
  String buildXtreamActionUrl({
    required String baseUrl,
    required String username,
    required String password,
    required String action,
    String? paramsJson,
  });

  /// Build an Xtream stream URL.
  String buildXtreamStreamUrl({
    required String baseUrl,
    required String username,
    required String password,
    required int streamId,
    required String streamType,
    required String extension,
  });

  /// Build an Xtream catchup/timeshift URL.
  String buildXtreamCatchupUrl({
    required String baseUrl,
    required String username,
    required String password,
    required int streamId,
    required int startUtc,
    required int durationMinutes,
  });

  // ── PIN Hashing ──────────────────────────────────────

  /// Hash a PIN using SHA-256.
  /// Returns 64-char hex hash.
  Future<String> hashPin(String pin);

  /// Verify a PIN against a stored hash.
  Future<bool> verifyPin(String inputPin, String storedHash);

  /// Check if a value looks like a SHA-256 hash.
  bool isHashedPin(String value);

  // ── Recommendations ──────────────────────────────────

  /// Compute recommendation sections from VOD items,
  /// channels, and watch history.
  /// Returns JSON array of RecommendationSection.
  Future<String> computeRecommendations({
    required String vodItemsJson,
    required String channelsJson,
    required String historyJson,
    required List<String> favoriteChannelIds,
    required List<String> favoriteVodIds,
    required int maxAllowedRating,
    required int nowUtcMs,
  });

  // ── Cloud Sync ───────────────────────────────────────

  /// Merge local and cloud backup JSON objects.
  /// Returns the merged JSON string.
  Future<String> mergeCloudBackups(
    String localJson,
    String cloudJson,
    String currentDeviceId,
  );

  // ── Search ───────────────────────────────────────────

  /// Search channels, VOD, and EPG.
  /// Returns JSON of SearchResults.
  Future<String> searchContent({
    required String query,
    required String channelsJson,
    required String vodItemsJson,
    required String epgEntriesJson,
    required String filterJson,
  });

  /// Enrich search results with channel/VOD metadata.
  /// Returns JSON array of EnrichedSearchResult.
  Future<String> enrichSearchResults(
    String resultsJson,
    String channelsJson,
    String vodItemsJson,
  );

  // ── Sorting ──────────────────────────────────────────

  /// Sort channels by number then name.
  /// Returns sorted JSON array of channels.
  Future<String> sortChannelsJson(String channelsJson);

  // ── Category Resolution ──────────────────────────────

  /// Resolve category IDs to names in channels.
  Future<String> resolveChannelCategories(
    String channelsJson,
    String catMapJson,
  );

  /// Resolve category IDs to names in VOD items.
  Future<String> resolveVodCategories(String itemsJson, String catMapJson);

  /// Extract unique sorted group names from channels.
  Future<List<String>> extractSortedGroups(String channelsJson);

  /// Extract unique sorted category names from VOD.
  Future<List<String>> extractSortedVodCategories(String itemsJson);

  // ── Watch Thresholds ────────────────────────────────

  /// Completion threshold (0.95): items at or above
  /// this progress ratio are considered finished.
  ///
  /// Canonical value owned by Rust `watch_progress.rs`.
  double completionThreshold();

  /// Next-episode threshold (0.90): items at or above
  /// this progress ratio trigger next-episode suggestions.
  ///
  /// Canonical value owned by Rust `watch_progress.rs`.
  double nextEpisodeThreshold();

  // ── Watch Progress ──────────────────────────────────

  /// Calculate progress ratio from position/duration.
  /// Returns clamped 0.0-1.0.
  double calculateWatchProgress(int positionMs, int durationMs);

  /// Filter watch positions for continue watching.
  /// Returns JSON array of WatchPositionEntry.
  Future<String> filterContinueWatchingPositions(String json, int limit);

  // ── Playback Duration Formatting ─────────────────────

  /// Format a playback position as "HH:MM:SS" or "MM:SS".
  ///
  /// Hours are shown when [durationMs] >= 1 hour.
  /// [positionMs] is the current playback position in ms.
  /// [durationMs] is the total media duration in ms.
  String formatPlaybackDuration(int positionMs, int durationMs);

  // ── Group Icon ──────────────────────────────────────

  /// Match a group name to a Material icon identifier.
  String matchGroupIcon(String groupName);

  // ── Search Grouping ─────────────────────────────────

  /// Group enriched search results by media type.
  /// Returns JSON of GroupedResults.
  Future<String> groupSearchResults(
    String resultsJson,
    String channelsJson,
    String vodJson,
    String epgJson,
  );

  // ── Normalize Utilities ──────────────────────────────

  /// Validate a MAC address format.
  bool validateMacAddress(String mac);

  /// Strip colons from a MAC address.
  String macToDeviceId(String mac);

  /// Guess search domains for channel logo lookup.
  List<String> guessLogoDomains(String name);

  // ── Timezone Formatting ──────────────────────────────

  /// Returns the UTC offset in minutes for the given IANA timezone name
  /// at the given epoch millisecond. DST-aware via chrono-tz.
  ///
  /// Returns 0 for "system", "UTC", or unknown timezone names.
  int getTimezoneOffsetMinutes(String tzName, int epochMs);

  /// Applies the DST-aware timezone offset to a UTC epochMs.
  /// Returns adjusted epochMs for display purposes.
  /// Returns epochMs unchanged for "system", "UTC", or unknown timezones.
  int applyTimezoneOffset(int epochMs, String tzName);

  /// Formats epochMs as "HH:MM:SS" in the given IANA timezone.
  /// DST-aware. Falls back to UTC for "system", "UTC", or unknown timezones.
  String formatTimeWithSeconds(int epochMs, String tzName);

  /// Format a timestamp as "HH:MM" in a timezone.
  String formatEpgTime(int timestampMs, double offsetHours);

  /// Format a timestamp as "Day DD Mon HH:MM".
  String formatEpgDatetime(int timestampMs, double offsetHours);

  /// Format duration in minutes as "Xh Ym".
  String formatDurationMinutes(int minutes);

  /// Calculate duration between timestamps in minutes.
  int durationBetweenMs(int startMs, int endMs);

  // ── VOD Sorting & Categorization ───────────────────

  /// Sort VOD items by the given criterion.
  /// Returns JSON array of VodItem.
  Future<String> sortVodItems(String itemsJson, String sortBy);

  /// Group VOD items by category.
  /// Returns JSON VodCategoryMap.
  Future<String> buildVodCategoryMap(String itemsJson);

  /// Filter and rank top VOD items by rating.
  /// Returns JSON array of VodItem.
  Future<String> filterTopVod(String itemsJson, int limit);

  /// Compute per-episode progress for a series.
  /// Returns JSON EpisodeProgressResult.
  Future<String> computeEpisodeProgress(String historyJson, String seriesId);

  /// Compute episode progress from DB for a series.
  /// Returns JSON with progress_map keyed by
  /// stream_url and last_watched_url.
  Future<String> computeEpisodeProgressFromDb(String seriesId);

  /// Filter VOD items by content rating level.
  /// Items with rating <= maxRatingValue pass.
  /// Unrated items always pass.
  /// Rating: 0=G, 1=PG, 2=PG-13, 3=R, 4=NC-17,
  /// 5=Unrated
  Future<String> filterVodByContentRating(String itemsJson, int maxRatingValue);

  // ── URL Normalization ──────────────────────────────

  /// Normalize an API base URL to scheme://host[:port].
  String normalizeApiBaseUrl(String url);

  // ── Config Merge ───────────────────────────────────

  /// Deep-merge two JSON objects.
  String deepMergeJson(String baseJson, String overridesJson);

  /// Set a value at a dot-separated path in a JSON
  /// object.
  String setNestedValue(String mapJson, String dotPath, String valueJson);

  // ── Permission ─────────────────────────────────────

  /// Whether the given role can view a recording.
  bool canViewRecording(
    String role,
    String recordingOwnerId,
    String currentProfileId,
  );

  /// Whether the given role can delete a recording.
  bool canDeleteRecording(
    String role,
    String recordingOwnerId,
    String currentProfileId,
  );

  // ── Source Filter ──────────────────────────────────

  /// Filter channels by source access.
  /// Returns JSON array of channels.
  Future<String> filterChannelsBySource(
    String channelsJson,
    String accessibleSourceIdsJson,
    bool isAdmin,
  );

  // ── Cloud Sync Direction ─────────────────────────

  /// Determines cloud sync direction from timestamps
  /// and device IDs.
  ///
  /// Returns one of: `"upload"`, `"download"`,
  /// `"no_change"`, or `"conflict"`.
  ///
  /// Pure CPU — no DB access required.
  String determineSyncDirection(
    int localMs,
    int cloudMs,
    int lastSyncMs,
    String localDevice,
    String cloudDevice,
  );

  // ── DVR: Recordings to Start ─────────────────────

  /// Returns JSON array of recording IDs that should
  /// start now.
  ///
  /// Input: JSON array of recording objects.
  /// Returns: JSON array of ID strings.
  Future<String> getRecordingsToStart(String recordingsJson, int nowMs);

  // ── EPG Window Merge ─────────────────────────────

  /// Merges new EPG entries into existing,
  /// deduplicating by startTime.
  ///
  /// Both inputs and output are JSON:
  /// `{ "channelId": [ { "startTime": epochMs, ... } ] }`
  Future<String> mergeEpgWindow(String existingJson, String newJson);
}
