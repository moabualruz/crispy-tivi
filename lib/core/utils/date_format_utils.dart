/// Formats a [DateTime] as "HH:mm" (24-hour clock).
String formatHHmm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

/// Formats a [DateTime] as "D/M/YYYY".
String formatDMY(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

/// Formats a [DateTime] as "YYYY-MM-DD".
String formatYMD(DateTime dt) =>
    '${dt.year}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

/// Formats a [DateTime] as "D/M/YYYY HH:mm".
String formatDMYHHmm(DateTime dt) => '${formatDMY(dt)} ${formatHHmm(dt)}';
