import '../../../../core/utils/format_utils.dart';
import '../entities/recording.dart';

// ──────────────────────────────────────────────────────────────
//  Public domain models
// ──────────────────────────────────────────────────────────────

/// Per-category storage summary (pure domain — no Flutter imports).
class CategoryBreakdown {
  const CategoryBreakdown({
    required this.label,
    required this.count,
    required this.bytes,
  });

  /// Human-readable category name (e.g. "Completed", "Failed").
  final String label;

  /// Number of recordings in this category.
  final int count;

  /// Total file size of recordings in this category (bytes).
  final int bytes;

  /// Size in megabytes.
  double get mb => bytes / (1024 * 1024);

  /// Formatted size label, e.g. "12.3 MB".
  String get mbLabel => formatBytes(bytes);
}

/// A recording recommended for clean-up, with a human-readable
/// reason.
class CleanUpCandidate {
  const CleanUpCandidate({required this.recording, required this.reason});

  /// The recording that may be deleted.
  final Recording recording;

  /// Why this recording is a clean-up candidate.
  final String reason;
}

/// Aggregated storage data computed from a list of [Recording]s.
class StorageBreakdownData {
  const StorageBreakdownData({
    required this.totalBytes,
    required this.totalCount,
    required this.categories,
    required this.channelBytes,
    required this.channelCounts,
    required this.cleanUpCandidates,
  });

  /// Sum of all recording file sizes (bytes).
  final int totalBytes;

  /// Total number of recordings (all statuses).
  final int totalCount;

  /// Breakdown per recording status.
  final List<CategoryBreakdown> categories;

  /// Total bytes per channel name (completed recordings only).
  final Map<String, int> channelBytes;

  /// Recording count per channel name (completed recordings only).
  final Map<String, int> channelCounts;

  /// Recordings suggested for deletion (capped at 10).
  final List<CleanUpCandidate> cleanUpCandidates;

  /// Total size in megabytes.
  double get totalMB => totalBytes / (1024 * 1024);

  /// Formatted total size label, e.g. "42.0 MB".
  String get totalMBLabel => formatBytes(totalBytes);
}

// ──────────────────────────────────────────────────────────────
//  Pure computation function
// ──────────────────────────────────────────────────────────────

/// Computes storage breakdown statistics from [recordings].
///
/// [now] is injectable for testing; defaults to [DateTime.now()].
StorageBreakdownData computeStorageBreakdown(
  List<Recording> recordings, {
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();

  final completed =
      recordings.where((r) => r.status == RecordingStatus.completed).toList();
  final scheduled =
      recordings.where((r) => r.status == RecordingStatus.scheduled).toList();
  final inProgress =
      recordings.where((r) => r.status == RecordingStatus.recording).toList();
  final failed =
      recordings.where((r) => r.status == RecordingStatus.failed).toList();

  int bytesFor(List<Recording> recs) =>
      recs.fold(0, (sum, r) => sum + (r.fileSizeBytes ?? 0));

  // Per-channel breakdown from completed recordings.
  final channelBytes = <String, int>{};
  final channelCounts = <String, int>{};
  for (final r in completed) {
    channelBytes[r.channelName] =
        (channelBytes[r.channelName] ?? 0) + (r.fileSizeBytes ?? 0);
    channelCounts[r.channelName] = (channelCounts[r.channelName] ?? 0) + 1;
  }

  final categories = [
    CategoryBreakdown(
      label: 'Completed',
      count: completed.length,
      bytes: bytesFor(completed),
    ),
    if (inProgress.isNotEmpty)
      CategoryBreakdown(
        label: 'In Progress',
        count: inProgress.length,
        bytes: bytesFor(inProgress),
      ),
    if (scheduled.isNotEmpty)
      CategoryBreakdown(label: 'Scheduled', count: scheduled.length, bytes: 0),
    if (failed.isNotEmpty)
      CategoryBreakdown(
        label: 'Failed',
        count: failed.length,
        bytes: bytesFor(failed),
      ),
  ];

  // Clean-up candidates: completed recordings older than 30 days,
  // plus all failed recordings.
  final cutoff = effectiveNow.subtract(const Duration(days: 30));
  final cleanUpCandidates = <CleanUpCandidate>[
    for (final r in completed)
      if (r.endTime.isBefore(cutoff))
        CleanUpCandidate(recording: r, reason: 'Recorded over 30 days ago'),
    for (final r in failed)
      CleanUpCandidate(recording: r, reason: 'Failed recording'),
  ];

  return StorageBreakdownData(
    totalBytes: bytesFor(recordings),
    totalCount: recordings.length,
    categories: categories,
    channelBytes: channelBytes,
    channelCounts: channelCounts,
    cleanUpCandidates: cleanUpCandidates.take(10).toList(),
  );
}
