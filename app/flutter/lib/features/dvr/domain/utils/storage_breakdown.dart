import '../../../../core/utils/format_utils.dart';
import '../entities/recording.dart';
import '../entities/recording_profile.dart';

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

  /// Deserialises a [CategoryBreakdown] from the map returned
  /// by the Rust [computeStorageBreakdown] algorithm.
  factory CategoryBreakdown.fromJson(Map<String, dynamic> m) {
    return CategoryBreakdown(
      label: m['label'] as String,
      count: m['count'] as int,
      bytes: m['bytes'] as int,
    );
  }
}

/// A recording recommended for clean-up, with a human-readable
/// reason.
class CleanUpCandidate {
  const CleanUpCandidate({required this.recording, required this.reason});

  /// The recording that may be deleted.
  final Recording recording;

  /// Why this recording is a clean-up candidate.
  final String reason;

  /// Deserialises a [CleanUpCandidate] from the map returned
  /// by the Rust [computeStorageBreakdown] algorithm.
  factory CleanUpCandidate.fromJson(Map<String, dynamic> m) {
    return CleanUpCandidate(
      recording: _recordingFromJson(m['recording'] as Map<String, dynamic>),
      reason: m['reason'] as String,
    );
  }
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

  /// Deserialises a [StorageBreakdownData] from the JSON map
  /// returned by the Rust [computeStorageBreakdown] algorithm.
  factory StorageBreakdownData.fromJson(Map<String, dynamic> m) {
    final categoriesRaw = m['categories'] as List<dynamic>;
    final channelBytesRaw = (m['channel_bytes'] as Map<String, dynamic>?) ?? {};
    final channelCountsRaw =
        (m['channel_counts'] as Map<String, dynamic>?) ?? {};
    final candidatesRaw = m['clean_up_candidates'] as List<dynamic>;

    return StorageBreakdownData(
      totalBytes: m['total_bytes'] as int,
      totalCount: m['total_count'] as int,
      categories:
          categoriesRaw
              .cast<Map<String, dynamic>>()
              .map(CategoryBreakdown.fromJson)
              .toList(),
      channelBytes: channelBytesRaw.map((k, v) => MapEntry(k, v as int)),
      channelCounts: channelCountsRaw.map((k, v) => MapEntry(k, v as int)),
      cleanUpCandidates:
          candidatesRaw
              .cast<Map<String, dynamic>>()
              .map(CleanUpCandidate.fromJson)
              .toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Internal helpers
// ──────────────────────────────────────────────────────────────

/// Deserialises a [Recording] from a map embedded inside the
/// Rust [computeStorageBreakdown] / [filterDvrRecordings] JSON.
///
/// Mirrors [_mapToRecording] in `cache_service_dvr.dart`.
Recording _recordingFromJson(Map<String, dynamic> m) {
  final profileName = m['profile'] as String?;
  final profile =
      profileName != null
          ? RecordingProfile.values.firstWhere(
            (p) => p.name == profileName,
            orElse: () => RecordingProfile.original,
          )
          : RecordingProfile.original;

  AutoDeletePolicy parseAutoDeletePolicy(String? name) {
    if (name == null) return AutoDeletePolicy.keepAll;
    return AutoDeletePolicy.values.firstWhere(
      (p) => p.name == name,
      orElse: () => AutoDeletePolicy.keepAll,
    );
  }

  DateTime parseNaive(String s) {
    final dt = DateTime.parse(s);
    return dt.isUtc
        ? dt
        : DateTime.utc(
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
          dt.millisecond,
          dt.microsecond,
        );
  }

  return Recording(
    id: m['id'] as String,
    channelId: m['channel_id'] as String?,
    channelName: m['channel_name'] as String,
    channelLogoUrl: m['channel_logo_url'] as String?,
    programName: m['program_name'] as String,
    streamUrl: m['stream_url'] as String?,
    startTime: parseNaive(m['start_time'] as String),
    endTime: parseNaive(m['end_time'] as String),
    status: RecordingStatus.values.byName(m['status'] as String),
    filePath: m['file_path'] as String?,
    fileSizeBytes: m['file_size_bytes'] as int?,
    isRecurring: m['is_recurring'] as bool? ?? false,
    recurDays: m['recur_days'] as int? ?? 0,
    profile: profile,
    ownerProfileId: m['owner_profile_id'] as String?,
    isShared: m['is_shared'] as bool? ?? true,
    remoteBackendId: m['remote_backend_id'] as String?,
    remotePath: m['remote_path'] as String?,
    autoDeletePolicy: parseAutoDeletePolicy(m['auto_delete_policy'] as String?),
    keepEpisodeCount: m['keep_episode_count'] as int? ?? 5,
  );
}
