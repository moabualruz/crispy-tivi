/// Formats a [DateTime] as a relative time string.
///
/// Examples:
/// - "Just now" (< 1 minute ago)
/// - "5m ago" (< 1 hour ago)
/// - "2h ago" (< 24 hours ago)
/// - "Yesterday" (1 day ago)
/// - "3d ago" (< 7 days ago)
/// - "1/15/2026" (7+ days ago)
///
/// The optional [now] parameter allows testable usage without
/// mocking [DateTime.now].
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.month}/${time.day}/${time.year}';
}
