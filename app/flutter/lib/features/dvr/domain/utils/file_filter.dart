export 'package:crispy_tivi/core/utils/file_extensions.dart'
    show FileExtensions;

// ── File-type filter (FE-CB-02) ────────────────────────────────────────────

/// File type filter categories for the cloud browser chip bar.
enum FileTypeFilter {
  all('All'),
  video('Video'),
  audio('Audio'),
  subtitle('Subtitle'),
  other('Other');

  const FileTypeFilter(this.label);

  /// Human-readable chip label.
  final String label;
}

// ── Sort options (FE-CB-03) ────────────────────────────────────────────────

/// Client-side sort orders for remote file listings.
enum SortOrder {
  nameAsc('Name A–Z'),
  nameDesc('Name Z–A'),
  dateNewest('Date Newest'),
  dateOldest('Date Oldest'),
  sizeLargest('Size Largest'),
  sizeSmallest('Size Smallest');

  const SortOrder(this.label);

  /// Human-readable sort label.
  final String label;
}
