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
