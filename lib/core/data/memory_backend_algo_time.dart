part of 'memory_backend.dart';

/// Time, timezone, watch-progress, and
/// playback-duration algorithm implementations
/// for [MemoryBackend].
mixin _MemoryAlgoTimeMixin on _MemoryStorage {
  // ── Watch History Algorithms ───────────────────

  Future<String> filterContinueWatching(
    String historyJson, {
    String? mediaType,
    String? profileId,
  }) async => '[]';

  Future<String> filterCrossDevice(
    String historyJson,
    String currentDeviceId,
    int cutoffUtcMs,
  ) async => '[]';

  // ── Watch Progress ─────────────────────────────

  /// Delegates to shared [dartCalculateWatchProgress].
  double calculateWatchProgress(int positionMs, int durationMs) =>
      dartCalculateWatchProgress(positionMs, durationMs);

  Future<String> filterContinueWatchingPositions(String json, int limit) async {
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    final filtered =
        list.where((e) {
          final pos = e['position_ms'] as int? ?? 0;
          final dur = e['duration_ms'] as int? ?? 0;
          if (dur <= 0) return false;
          final progress = pos / dur;
          return progress > 0.0 && progress < kCompletionThreshold;
        }).toList();
    filtered.sort((a, b) {
      final la = a['last_watched'] as String? ?? '';
      final lb = b['last_watched'] as String? ?? '';
      return lb.compareTo(la);
    });
    if (filtered.length > limit) {
      filtered.removeRange(limit, filtered.length);
    }
    return jsonEncode(filtered);
  }

  // ── Playback Duration Formatting ──────────────

  /// Delegates to shared [dartFormatPlaybackDuration].
  String formatPlaybackDuration(int positionMs, int durationMs) =>
      dartFormatPlaybackDuration(positionMs, durationMs);

  // ── DST-aware Timezone ─────────────────────────

  /// Delegates to shared [dartGetTimezoneOffsetMinutes].
  int getTimezoneOffsetMinutes(String tzName, int epochMs) =>
      dartGetTimezoneOffsetMinutes(tzName, epochMs);

  /// Delegates to shared [dartApplyTimezoneOffset].
  int applyTimezoneOffset(int epochMs, String tzName) =>
      dartApplyTimezoneOffset(epochMs, tzName);

  /// Delegates to shared [dartFormatTimeWithSeconds].
  String formatTimeWithSeconds(int epochMs, String tzName) =>
      dartFormatTimeWithSeconds(epochMs, tzName);

  // ── EPG Timezone Formatting ────────────────────

  /// Delegates to shared [dartFormatEpgTime].
  String formatEpgTime(int timestampMs, double offsetHours) =>
      dartFormatEpgTime(timestampMs, offsetHours);

  /// Delegates to shared [dartFormatEpgDatetime].
  String formatEpgDatetime(int timestampMs, double offsetHours) =>
      dartFormatEpgDatetime(timestampMs, offsetHours);

  /// Delegates to shared [dartFormatDurationMinutes].
  String formatDurationMinutes(int minutes) =>
      dartFormatDurationMinutes(minutes);

  /// Delegates to shared [dartDurationBetweenMs].
  int durationBetweenMs(int startMs, int endMs) =>
      dartDurationBetweenMs(startMs, endMs);
}
