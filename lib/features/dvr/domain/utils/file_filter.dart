import 'package:crispy_tivi/core/utils/file_extensions.dart';

import '../storage_provider.dart';

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

/// Returns `true` if [name] matches the given [filter].
///
/// Pure function — no Flutter or framework imports.
bool matchesFilter(String name, FileTypeFilter filter) {
  if (filter == FileTypeFilter.all) return true;
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  switch (filter) {
    case FileTypeFilter.video:
      return FileExtensions.video.contains(ext);
    case FileTypeFilter.audio:
      return FileExtensions.audio.contains(ext);
    case FileTypeFilter.subtitle:
      return FileExtensions.subtitle.contains(ext);
    case FileTypeFilter.all:
      return true;
    case FileTypeFilter.other:
      return !matchesFilter(name, FileTypeFilter.video) &&
          !matchesFilter(name, FileTypeFilter.audio) &&
          !matchesFilter(name, FileTypeFilter.subtitle);
  }
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

/// Sorts [files] according to [order].
///
/// Directories are always surfaced first regardless of order.
/// Pure function — no Flutter or framework imports.
List<RemoteFile> sortFiles(List<RemoteFile> files, SortOrder order) {
  final dirs = files.where((f) => f.isDirectory).toList();
  final nonDirs = files.where((f) => !f.isDirectory).toList();

  int Function(RemoteFile, RemoteFile) comparator;
  switch (order) {
    case SortOrder.nameAsc:
      comparator =
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    case SortOrder.nameDesc:
      comparator =
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase());
    case SortOrder.dateNewest:
      comparator = (a, b) => b.modifiedAt.compareTo(a.modifiedAt);
    case SortOrder.dateOldest:
      comparator = (a, b) => a.modifiedAt.compareTo(b.modifiedAt);
    case SortOrder.sizeLargest:
      comparator = (a, b) => b.sizeBytes.compareTo(a.sizeBytes);
    case SortOrder.sizeSmallest:
      comparator = (a, b) => a.sizeBytes.compareTo(b.sizeBytes);
  }

  dirs.sort(comparator);
  nonDirs.sort(comparator);
  return [...dirs, ...nonDirs];
}
