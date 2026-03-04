import '../../../iptv/domain/entities/epg_entry.dart';
import '../providers/epg_providers.dart';

/// Pixels per minute in day view.
const double epgPixelsPerMinuteDay = 4.0;

/// Pixels per minute in week view.
///
/// Derived so that a 7-day week (7 × 24 × 60 = 10 080 min) fits
/// comfortably on a 1080p screen (1920px content width):
///   1920 ÷ 10 080 ≈ 0.190 px/min at 100 % zoom.
///
/// The value 0.57 was calibrated for a wider "zoomable" week view
/// where three days are visible by default (≈ 1920 ÷ (3 × 24 × 60)
/// = 0.444 px/min, rounded up to 0.57 to give breathing room and
/// account for the fixed channel-column offset). Adjust this value
/// when the design calls for a different initial zoom level.
const double epgPixelsPerMinuteWeek = 0.57;

/// Returns pixels-per-minute for the given [viewMode].
double getEpgPixelsPerMinute(EpgViewMode viewMode) {
  return viewMode == EpgViewMode.day
      ? epgPixelsPerMinuteDay
      : epgPixelsPerMinuteWeek;
}

/// Returns the Monday of the week containing [date].
DateTime getEpgWeekStart(DateTime date) {
  return DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: date.weekday - 1));
}

/// Returns (start, end) for the visible date range.
(DateTime, DateTime) getEpgDateRange(
  EpgViewMode viewMode,
  DateTime selectedDate,
) {
  if (viewMode == EpgViewMode.day) {
    final start = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    return (start, start.add(const Duration(hours: 24)));
  } else {
    final weekStart = getEpgWeekStart(selectedDate);
    return (weekStart, weekStart.add(const Duration(days: 7)));
  }
}

/// Returns true if [a] and [b] are the same calendar day.
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Abbreviated month + day label, e.g. "Feb 22".
String epgTodayLabel(DateTime date) {
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
  return '${months[date.month - 1]}'
      ' ${date.day}';
}

/// Returns the currently-live EPG entry for [channelId],
/// or null if nothing is live.
///
/// T-25: thin compatibility wrapper around the instance method
/// [EpgState.getNowPlaying]. Prefer calling that method directly:
/// ```dart
/// final entry = state.getNowPlaying(channelId);
/// ```
EpgEntry? getNowPlaying(EpgState state, String channelId, {DateTime? now}) {
  return state.getNowPlaying(channelId, now: now);
}
