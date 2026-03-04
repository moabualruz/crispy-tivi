import 'dart:convert';

import 'timezone_offsets.dart';

/// Pure-Dart EPG time formatting and timezone utilities.
///
/// Synchronous local fallbacks shared by [WsBackend] and
/// [MemoryBackend]. Also includes watch-progress and playback
/// duration helpers that have no async dependency.
///
/// Mirrors the Rust functions in
/// `crispy-core::algorithms::timezone`.

// ── Watch Progress ────────────────────────────────────────────────

/// Returns play progress as a fraction in [0.0, 1.0].
///
/// Returns 0.0 when [durationMs] ≤ 0.
double dartCalculateWatchProgress(int positionMs, int durationMs) {
  if (durationMs <= 0) return 0.0;
  return (positionMs / durationMs).clamp(0.0, 1.0);
}

// ── Playback Duration Formatting ──────────────────────────────────

/// Format a playback position as `mm:ss` or `hh:mm:ss`.
///
/// Shows the hours component when [durationMs] ≥ 1 hour.
String dartFormatPlaybackDuration(int positionMs, int durationMs) {
  final totalMs = positionMs < 0 ? 0 : positionMs;
  final hours = totalMs ~/ 3600000;
  final minutes = (totalMs % 3600000) ~/ 60000;
  final seconds = (totalMs % 60000) ~/ 1000;
  final showHours = durationMs >= 3600000;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (showHours) {
    final hh = hours.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
  return '$mm:$ss';
}

// ── EPG Timezone Formatting ───────────────────────────────────────

/// Format a UTC timestamp as `HH:mm` in the given UTC offset.
///
/// [offsetHours] is a fractional hour offset (e.g. 5.5 for IST).
String dartFormatEpgTime(int timestampMs, double offsetHours) {
  final offsetMs = (offsetHours * 3600000).round();
  final dt = DateTime.fromMillisecondsSinceEpoch(
    timestampMs + offsetMs,
    isUtc: true,
  );
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Format a UTC timestamp as `Www dd Mon HH:mm` in the given offset.
String dartFormatEpgDatetime(int timestampMs, double offsetHours) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final offsetMs = (offsetHours * 3600000).round();
  final dt = DateTime.fromMillisecondsSinceEpoch(
    timestampMs + offsetMs,
    isUtc: true,
  );
  final day = days[dt.weekday - 1];
  final mon = months[dt.month - 1];
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$day $d $mon $h:$m';
}

/// Format an integer minute count as `Xm` or `Xh Ym`.
///
/// 60 min → `"1h 0m"` (always shows minutes when ≥ 1 hour).
/// Mirrors `crispy-core::algorithms::timezone::format_duration_minutes`.
String dartFormatDurationMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h}h ${m}m';
}

/// Return the number of whole minutes between [startMs] and [endMs].
int dartDurationBetweenMs(int startMs, int endMs) =>
    ((endMs - startMs) / 60000).round();

// ── DST-aware Timezone ────────────────────────────────────────────

/// Return the UTC offset in minutes for [tzName] at [epochMs].
///
/// Uses a static table ([kStaticTimezoneOffsetMinutes]) — does NOT
/// account for DST. Falls back to 0 for unknown timezone names.
int dartGetTimezoneOffsetMinutes(String tzName, int epochMs) {
  if (tzName == 'system') {
    return DateTime.now().timeZoneOffset.inMinutes;
  }
  return kStaticTimezoneOffsetMinutes[tzName] ?? 0;
}

/// Shift [epochMs] by the UTC offset of [tzName].
int dartApplyTimezoneOffset(int epochMs, String tzName) {
  final offsetMinutes = dartGetTimezoneOffsetMinutes(tzName, epochMs);
  return epochMs + offsetMinutes * 60000;
}

/// Format [epochMs] as `HH:mm:ss` in the local clock of [tzName].
String dartFormatTimeWithSeconds(int epochMs, String tzName) {
  final adjusted = dartApplyTimezoneOffset(epochMs, tzName);
  final dt = DateTime.fromMillisecondsSinceEpoch(adjusted, isUtc: true);
  return '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

// ── EPG Window Merge ──────────────────────────────────────────────

/// Merge two EPG window JSON objects.
///
/// Format: `{"channelId": [{"startTime": epochMs, ...}]}`.
/// New entries whose `startTime` already exists are discarded.
/// Entries per channel are sorted by `startTime` ascending.
///
/// Mirrors `crispy-core::algorithms::epg_window_merge`.
Future<String> dartMergeEpgWindow(String existingJson, String newJson) async {
  Map<String, dynamic> existing;
  Map<String, dynamic> incoming;
  try {
    existing = jsonDecode(existingJson) as Map<String, dynamic>;
  } catch (_) {
    existing = {};
  }
  try {
    incoming = jsonDecode(newJson) as Map<String, dynamic>;
  } catch (_) {
    incoming = {};
  }
  final merged = Map<String, dynamic>.from(existing);
  for (final channelId in incoming.keys) {
    final newEntries =
        (incoming[channelId] as List).cast<Map<String, dynamic>>();
    if (!merged.containsKey(channelId)) {
      merged[channelId] = newEntries;
    } else {
      final existingEntries =
          (merged[channelId] as List).cast<Map<String, dynamic>>();
      final existingStarts =
          existingEntries.map((e) => e['startTime'] as int? ?? -1).toSet();
      final added =
          newEntries
              .where(
                (e) => !existingStarts.contains(e['startTime'] as int? ?? -1),
              )
              .toList();
      final combined = [...existingEntries, ...added];
      combined.sort(
        (a, b) => (a['startTime'] as int? ?? 0).compareTo(
          b['startTime'] as int? ?? 0,
        ),
      );
      merged[channelId] = combined;
    }
  }
  return jsonEncode(merged);
}
