// General formatting utilities.

/// Formats a byte count as a human-readable string.
///
/// Returns "X.X KB", "X.X MB", or "X.X GB" depending on magnitude.
String formatBytes(int bytes) {
  const int kBytesPerGb = 1024 * 1024 * 1024;
  const int kBytesPerMb = 1024 * 1024;
  const int kBytesPerKb = 1024;
  if (bytes >= kBytesPerGb) {
    return '${(bytes / kBytesPerGb).toStringAsFixed(1)} GB';
  }
  if (bytes >= kBytesPerMb) {
    return '${(bytes / kBytesPerMb).toStringAsFixed(1)} MB';
  }
  return '${(bytes / kBytesPerKb).toStringAsFixed(1)} KB';
}

/// Formats a duration given in milliseconds as a compact human-readable string.
///
/// Returns strings like "42m" for durations under an hour, or "1h 2m"
/// for longer durations. Returns `null` when [ms] is `null`.
///
/// Used by media-server screens (Jellyfin, Emby, Plex) to display
/// episode / movie runtime.
String? formatDurationMs(int? ms) {
  if (ms == null) return null;
  final h = ms ~/ 3600000;
  final m = (ms % 3600000) ~/ 60000;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
