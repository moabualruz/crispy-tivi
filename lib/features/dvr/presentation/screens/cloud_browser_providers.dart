import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/toggle_notifier.dart';
import '../../domain/storage_provider.dart';
import '../../domain/utils/file_filter.dart';

// ── Constants ──────────────────────────────────────────────────────

/// Maximum number of recent files tracked in session memory. (FE-CB-09)
const int kMaxRecentFiles = 5;

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
class MultiSelectNotifier extends ToggleNotifier {
  void activate() => state = true;
  void deactivate() => state = false;
}

final multiSelectActiveProvider = NotifierProvider<MultiSelectNotifier, bool>(
  MultiSelectNotifier.new,
);

// ── FE-CB-08: Upload state ─────────────────────────────────────────

/// Whether an upload is currently in progress.
class UploadActiveNotifier extends ToggleNotifier {
  void setActive(bool active) => state = active;
}

final uploadActiveProvider = NotifierProvider<UploadActiveNotifier, bool>(
  UploadActiveNotifier.new,
);

// ── Sync status enum (FE-CB-06) ────────────────────────────────────

enum SyncStatus { none, uploading, synced, error }
