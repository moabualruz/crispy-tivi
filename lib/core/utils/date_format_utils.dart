/// Formats [DateTime] as a NaiveDateTime string for Rust serde.
///
/// Rust's `NaiveDateTime` expects `"2024-01-01T15:00:00"` —
/// no timezone suffix, no fractional seconds. Dart's
/// `toIso8601String()` emits `"2024-01-01T15:00:00.000Z"` which
/// Rust cannot parse.
///
/// Always converts to UTC first so the value is stable regardless
/// of the device's local timezone.
String toNaiveDateTime(DateTime dt) {
  final utc = dt.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')}T'
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')}:'
      '${utc.second.toString().padLeft(2, '0')}';
}

/// Parses a NaiveDateTime string (no timezone) as UTC.
///
/// Rust's `NaiveDateTime` serde produces `"2024-01-01T15:00:00"`.
/// [DateTime.parse] treats this as local time; this helper
/// reinterprets it as UTC so the round-trip
/// `toNaiveDateTime` → `parseNaiveUtc` is lossless.
DateTime parseNaiveUtc(String s) {
  final dt = DateTime.parse(s);
  return dt.isUtc
      ? dt
      : DateTime.utc(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
        dt.millisecond,
        dt.microsecond,
      );
}

/// Formats a [DateTime] as "HH:mm" (24-hour clock).
///
/// Uses the [DateTime] value as-is (no timezone conversion).
/// For local-time display use [formatHHmmLocal].
String formatHHmm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

/// Formats a [DateTime] as "HH:mm" in local time (24-hour clock).
///
/// Converts to local time via [DateTime.toLocal] before formatting.
String formatHHmmLocal(DateTime dt) => formatHHmm(dt.toLocal());

/// Formats a [DateTime] as "h:mm AM/PM" in local time (12-hour clock).
///
/// Converts to local time via [DateTime.toLocal] before formatting.
/// Midnight is displayed as 12:xx AM, noon as 12:xx PM.
String formatH12mm(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour;
  final m = local.minute.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$m $period';
}

/// Formats a [DateTime] as "D/M/YYYY".
String formatDMY(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

/// Formats a [DateTime] as "YYYY-MM-DD".
String formatYMD(DateTime dt) =>
    '${dt.year}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

/// Formats a [DateTime] as "D/M/YYYY HH:mm".
String formatDMYHHmm(DateTime dt) => '${formatDMY(dt)} ${formatHHmm(dt)}';

/// Formats [totalSeconds] as `MM:SS` (both components zero-padded to 2 digits).
///
/// Used for countdown timers (auth expiry, PIN lockout, etc.).
/// Examples:
///   - 0 → "00:00"
///   - 90 → "01:30"
///   - 3599 → "59:59"
String formatMmss(int totalSeconds) {
  final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Formats a [Duration] as a human-readable "time remaining" label.
///
/// Returns:
///   - `""` for non-positive durations
///   - `"Xm left"` for durations under one hour
///   - `"Xh left"` for exact hour durations
///   - `"Xh Ym left"` otherwise
String formatTimeRemaining(Duration remaining) {
  final totalMinutes = remaining.inMinutes;
  if (totalMinutes <= 0) return '';
  if (totalMinutes < 60) return '${totalMinutes}m left';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '${hours}h left';
  return '${hours}h ${minutes}m left';
}
