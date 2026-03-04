import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/storage_provider.dart';

// ── Constants ──────────────────────────────────────────────────────

/// Maximum number of recent files tracked in session memory. (FE-CB-09)
const int kMaxRecentFiles = 5;

// ── File-type filter enum (FE-CB-02) ──────────────────────────────

/// File type filter categories for the chip bar.
enum FileTypeFilter {
  all('All'),
  video('Video'),
  audio('Audio'),
  subtitle('Subtitle'),
  other('Other');

  const FileTypeFilter(this.label);
  final String label;
}

/// Returns true if [name] matches the given [filter].
bool matchesFilter(String name, FileTypeFilter filter) {
  if (filter == FileTypeFilter.all) return true;
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  switch (filter) {
    case FileTypeFilter.video:
      return const {
        'mp4',
        'mkv',
        'avi',
        'mov',
        'ts',
        'mpg',
        'mpeg',
        'm2ts',
        'wmv',
        'flv',
        'webm',
        'm4v',
      }.contains(ext);
    case FileTypeFilter.audio:
      return const {
        'mp3',
        'aac',
        'flac',
        'ogg',
        'wav',
        'opus',
        'm4a',
        'wma',
        'ac3',
        'eac3',
      }.contains(ext);
    case FileTypeFilter.subtitle:
      return const {
        'srt',
        'ass',
        'ssa',
        'vtt',
        'sub',
        'idx',
        'sup',
        'dfxp',
        'ttml',
      }.contains(ext);
    case FileTypeFilter.all:
      return true;
    case FileTypeFilter.other:
      return !matchesFilter(name, FileTypeFilter.video) &&
          !matchesFilter(name, FileTypeFilter.audio) &&
          !matchesFilter(name, FileTypeFilter.subtitle);
  }
}

// ── Sort options (FE-CB-03) ────────────────────────────────────────

/// Client-side sort orders for remote file listings.
enum SortOrder {
  nameAsc('Name A–Z'),
  nameDesc('Name Z–A'),
  dateNewest('Date Newest'),
  dateOldest('Date Oldest'),
  sizeLargest('Size Largest'),
  sizeSmallest('Size Smallest');

  const SortOrder(this.label);
  final String label;
}

/// Sorts [files] according to [order].
///
/// Directories are always surfaced first regardless of order.
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

// ── Sort provider (FE-CB-03) ───────────────────────────────────────

class SortOrderNotifier extends Notifier<SortOrder> {
  @override
  SortOrder build() => SortOrder.nameAsc;

  void set(SortOrder order) => state = order;
}

final sortOrderProvider = NotifierProvider<SortOrderNotifier, SortOrder>(
  SortOrderNotifier.new,
);

// ── File-type filter provider (FE-CB-02) ──────────────────────────

class FileTypeFilterNotifier extends Notifier<FileTypeFilter> {
  @override
  FileTypeFilter build() => FileTypeFilter.all;

  void set(FileTypeFilter filter) => state = filter;
}

final fileTypeFilterProvider =
    NotifierProvider<FileTypeFilterNotifier, FileTypeFilter>(
      FileTypeFilterNotifier.new,
    );

// ── Recent files provider (FE-CB-09) ──────────────────────────────

/// Session-scoped list of recently opened remote files.
///
/// In-memory only — cleared on app restart.
class RecentFilesNotifier extends Notifier<List<RemoteFile>> {
  @override
  List<RemoteFile> build() => const [];

  /// Adds [file] to the front of the recent list, capping at
  /// [kMaxRecentFiles] entries. Deduplicates by path.
  void add(RemoteFile file) {
    final next =
        [
          file,
          ...state.where((f) => f.path != file.path),
        ].take(kMaxRecentFiles).toList();
    state = next;
  }
}

final recentFilesProvider =
    NotifierProvider<RecentFilesNotifier, List<RemoteFile>>(
      RecentFilesNotifier.new,
    );

// ── Selection providers ────────────────────────────────────────────

/// Tracks the set of selected file paths in multi-select mode.
class SelectedPathsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void setAll(Set<String> paths) => state = paths;
  void toggle(String path) {
    final next = Set<String>.from(state);
    if (next.contains(path)) {
      next.remove(path);
    } else {
      next.add(path);
    }
    state = next;
  }

  void clear() => state = const {};
}

final selectedPathsProvider =
    NotifierProvider<SelectedPathsNotifier, Set<String>>(
      SelectedPathsNotifier.new,
    );

/// Tracks whether multi-select mode is currently active.
class MultiSelectNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void activate() => state = true;
  void deactivate() => state = false;
}

final multiSelectActiveProvider = NotifierProvider<MultiSelectNotifier, bool>(
  MultiSelectNotifier.new,
);

// ── FE-CB-08: Upload state ─────────────────────────────────────────

/// Whether an upload is currently in progress.
class UploadActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool active) => state = active;
}

final uploadActiveProvider = NotifierProvider<UploadActiveNotifier, bool>(
  UploadActiveNotifier.new,
);

// ── Sync status enum (FE-CB-06) ────────────────────────────────────

enum SyncStatus { none, uploading, synced, error }
