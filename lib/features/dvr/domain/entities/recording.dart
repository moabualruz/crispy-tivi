import 'package:flutter/widgets.dart';

import '../../../../core/utils/format_utils.dart';
import 'recording_profile.dart';

/// Auto-delete policy applied when a recording series grows.
enum AutoDeletePolicy {
  /// Keep all episodes — never auto-delete.
  keepAll(
    label: 'Keep All',
    icon: IconData(0xe877, fontFamily: 'MaterialIcons'),
  ),

  /// Keep only the latest N episodes, deleting the oldest when
  /// the limit is exceeded. The limit is stored separately per
  /// recording via [Recording.keepEpisodeCount].
  keepN(
    label: 'Keep Latest N',
    icon: IconData(0xe8b8, fontFamily: 'MaterialIcons'),
  ),

  /// Delete the recording once it has been fully watched.
  deleteAfterWatching(
    label: 'Delete After Watching',
    icon: IconData(0xe872, fontFamily: 'MaterialIcons'),
  );

  const AutoDeletePolicy({required this.label, required this.icon});

  /// User-visible label.
  final String label;

  /// The associated Material icon.
  final IconData icon;
}

/// A DVR recording entry — scheduled, in-progress, or completed.
@immutable
class Recording {
  const Recording({
    required this.id,
    required this.channelName,
    required this.programName,
    required this.startTime,
    required this.endTime,
    this.channelId,
    this.channelLogoUrl,
    this.streamUrl,
    this.status = RecordingStatus.scheduled,
    this.filePath,
    this.fileSizeBytes,
    this.isRecurring = false,
    this.recurDays = 0,
    this.profile = RecordingProfile.original,
    this.ownerProfileId,
    this.isShared = true,
    this.remoteBackendId,
    this.remotePath,
    this.autoDeletePolicy = AutoDeletePolicy.keepAll,
    this.keepEpisodeCount = 5,
  });

  final String id;
  final String? channelId;
  final String channelName;
  final String? channelLogoUrl;
  final String programName;
  final String? streamUrl;
  final DateTime startTime;
  final DateTime endTime;
  final RecordingStatus status;
  final String? filePath;
  final int? fileSizeBytes;

  /// Whether this recording repeats on a schedule.
  final bool isRecurring;

  /// Bitmask for recurring days (Mon=1, Tue=2, Wed=4, Thu=8,
  /// Fri=16, Sat=32, Sun=64). 0 means not recurring (or daily=127).
  final int recurDays;

  /// Quality/format profile for this recording.
  final RecordingProfile profile;

  /// Profile ID of the user who scheduled this recording.
  /// Null = shared/system recording (visible to all).
  final String? ownerProfileId;

  /// Whether this recording is shared with other profiles.
  /// Only applies when ownerProfileId is set.
  final bool isShared;

  /// Storage backend ID if uploaded to cloud.
  final String? remoteBackendId;

  /// Path on the remote storage backend.
  final String? remotePath;

  /// Policy controlling how old episodes are auto-deleted.
  final AutoDeletePolicy autoDeletePolicy;

  /// Episode limit used when [autoDeletePolicy] is [AutoDeletePolicy.keepN].
  /// Ignored for other policies.
  final int keepEpisodeCount;

  Duration get duration => endTime.difference(startTime);

  String get fileSizeMB {
    if (fileSizeBytes == null) return '—';
    return formatBytes(fileSizeBytes!);
  }

  Recording copyWith({
    RecordingStatus? status,
    String? filePath,
    int? fileSizeBytes,
    String? streamUrl,
    bool? isRecurring,
    int? recurDays,
    RecordingProfile? profile,
    String? ownerProfileId,
    bool? isShared,
    bool clearOwner = false,
    String? remoteBackendId,
    String? remotePath,
    AutoDeletePolicy? autoDeletePolicy,
    int? keepEpisodeCount,
  }) {
    return Recording(
      id: id,
      channelId: channelId,
      channelName: channelName,
      channelLogoUrl: channelLogoUrl,
      programName: programName,
      streamUrl: streamUrl ?? this.streamUrl,
      startTime: startTime,
      endTime: endTime,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isRecurring: isRecurring ?? this.isRecurring,
      recurDays: recurDays ?? this.recurDays,
      profile: profile ?? this.profile,
      ownerProfileId:
          clearOwner ? null : (ownerProfileId ?? this.ownerProfileId),
      isShared: isShared ?? this.isShared,
      remoteBackendId: remoteBackendId ?? this.remoteBackendId,
      remotePath: remotePath ?? this.remotePath,
      autoDeletePolicy: autoDeletePolicy ?? this.autoDeletePolicy,
      keepEpisodeCount: keepEpisodeCount ?? this.keepEpisodeCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recording && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);
}

enum RecordingStatus { scheduled, recording, completed, failed }
