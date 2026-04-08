import '../data/crispy_backend.dart';

/// Centralized timezone utilities for EPG time display.
///
/// Provides consistent time formatting across all EPG widgets
/// using the user's configured timezone preference.
///
/// Call [setBackend] once at app startup to enable
/// Rust-backed DST-aware formatting.
class TimezoneUtils {
  /// Rust backend reference, set once at startup.
  static CrispyBackend? _backend;

  /// Sets the backend for Rust-delegated formatting.
  /// Must be called once before any format methods.
  static void setBackend(CrispyBackend backend) {
    _backend = backend;
  }

  /// Timezone display labels for UI.
  static const Map<String, String> timezoneLabels = {
    'system': 'System Default',
    'UTC': 'UTC (No offset)',
    'America/New_York': 'Eastern Time (ET)',
    'America/Chicago': 'Central Time (CT)',
    'America/Denver': 'Mountain Time (MT)',
    'America/Los_Angeles': 'Pacific Time (PT)',
    'America/Sao_Paulo': 'Brasilia Time (BRT)',
    'Europe/London': 'London (GMT/BST)',
    'Europe/Paris': 'Paris (CET/CEST)',
    'Europe/Berlin': 'Berlin (CET/CEST)',
    'Europe/Moscow': 'Moscow (MSK)',
    'Asia/Dubai': 'Dubai (GST)',
    'Asia/Kolkata': 'India (IST)',
    'Asia/Shanghai': 'Shanghai (CST)',
    'Asia/Tokyo': 'Tokyo (JST)',
    'Asia/Seoul': 'Seoul (KST)',
    'Australia/Sydney': 'Sydney (AEST/AEDT)',
  };

  /// Returns all available timezone options.
  static List<String> get availableTimezones => timezoneLabels.keys.toList();

  /// Gets the user-friendly label for a timezone.
  static String getLabel(String timezone) {
    return timezoneLabels[timezone] ?? timezone;
  }

  /// Gets the timezone offset as a display label (e.g., "UTC-5:00").
  ///
  /// DST-aware when a backend is available.
  static String getOffsetLabel(String timezone) {
    if (timezone == 'system') {
      final offset = DateTime.now().timeZoneOffset;
      return _formatOffsetAsLabel(offset);
    }
    final offset = getOffset(timezone);
    return _formatOffsetAsLabel(offset);
  }

  static String _formatOffsetAsLabel(Duration offset) {
    final hours = offset.inHours;
    final minutes = offset.inMinutes.abs() % 60;
    final sign = hours >= 0 ? '+' : '';
    if (minutes == 0) {
      return 'UTC$sign$hours:00';
    }
    return 'UTC$sign$hours:${minutes.toString().padLeft(2, '0')}';
  }

  /// Gets the timezone offset as a Duration. DST-aware via backend.
  ///
  /// For 'system', returns the device's current timezone offset.
  /// For IANA identifiers, queries the Rust backend for the current offset
  /// (DST-aware). Falls back to Duration.zero for unknown timezones when
  /// no backend is set.
  static Duration getOffset(String timezone) {
    if (timezone == 'system') {
      return DateTime.now().timeZoneOffset;
    }
    final b = _backend;
    if (b != null) {
      final minutes = b.getTimezoneOffsetMinutes(
        timezone,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      return Duration(minutes: minutes);
    }
    // No backend yet — fall back to UTC.
    return Duration.zero;
  }

  /// Applies the DST-aware timezone offset to a UTC DateTime.
  ///
  /// Returns the adjusted DateTime for display purposes.
  static DateTime applyTimezone(DateTime utcTime, String timezone) {
    if (timezone == 'system') {
      return utcTime.add(DateTime.now().timeZoneOffset);
    }
    final b = _backend;
    if (b != null) {
      final adjustedMs = b.applyTimezoneOffset(
        utcTime.millisecondsSinceEpoch,
        timezone,
      );
      return DateTime.fromMillisecondsSinceEpoch(adjustedMs, isUtc: true);
    }
    return utcTime;
  }

  /// Formats a UTC DateTime as HH:mm using the
  /// configured timezone. Delegates to Rust backend.
  static String formatTime(DateTime utcTime, String timezone) {
    final b = _backend;
    if (b != null) {
      return b.formatEpgTime(
        utcTime.millisecondsSinceEpoch,
        _offsetHours(timezone),
      );
    }
    final adjusted = applyTimezone(utcTime, timezone);
    return '${adjusted.hour.toString().padLeft(2, '0')}:'
        '${adjusted.minute.toString().padLeft(2, '0')}';
  }

  /// Formats a UTC DateTime as HH:mm:ss using the configured timezone.
  ///
  /// DST-aware when a backend is available.
  static String formatTimeWithSeconds(DateTime utcTime, String timezone) {
    final b = _backend;
    if (b != null) {
      return b.formatTimeWithSeconds(utcTime.millisecondsSinceEpoch, timezone);
    }
    // Dart fallback.
    final adjusted = applyTimezone(utcTime, timezone);
    return '${adjusted.hour.toString().padLeft(2, '0')}:'
        '${adjusted.minute.toString().padLeft(2, '0')}:'
        '${adjusted.second.toString().padLeft(2, '0')}';
  }

  /// Formats a UTC DateTime as a date string using the configured timezone.
  static String formatDate(DateTime utcTime, String timezone) {
    final adjusted = applyTimezone(utcTime, timezone);
    return '${adjusted.day}/${adjusted.month}/${adjusted.year}';
  }

  /// Formats a UTC DateTime with both date and time.
  /// Delegates to Rust backend when available.
  static String formatDateTime(DateTime utcTime, String timezone) {
    final b = _backend;
    if (b != null) {
      return b.formatEpgDatetime(
        utcTime.millisecondsSinceEpoch,
        _offsetHours(timezone),
      );
    }
    final adjusted = applyTimezone(utcTime, timezone);
    return '${adjusted.day}/${adjusted.month} '
        '${adjusted.hour.toString().padLeft(2, '0')}:'
        '${adjusted.minute.toString().padLeft(2, '0')}';
  }

  /// Gets the current time in the specified timezone.
  static DateTime nowIn(String timezone) {
    return applyTimezone(DateTime.now().toUtc(), timezone);
  }

  /// Converts a timezone string to offset hours for the Rust backend.
  ///
  /// DST-aware: queries the backend for the current offset.
  static double _offsetHours(String timezone) {
    final offset = getOffset(timezone);
    return offset.inMinutes / 60.0;
  }
}
