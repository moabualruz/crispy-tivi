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
