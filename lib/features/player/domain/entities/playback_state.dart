import 'package:flutter/foundation.dart';

import '../segment_skip_config.dart';

/// A time segment that may be skipped (intro, recap, credits).
@immutable
class SkipSegment {
  const SkipSegment({required this.start, required this.end, this.type});

  /// Start of the segment.
  final Duration start;

  /// End of the segment (exclusive).
  final Duration end;

  /// Explicit segment type from media server metadata.
  ///
  /// When `null`, the type is inferred from position heuristics
  /// via [inferSegmentType].
  final SegmentType? type;

  /// Whether [position] falls inside this segment.
  bool containsPosition(Duration position) =>
      position >= start && position < end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkipSegment &&
          start == other.start &&
          end == other.end &&
          type == other.type;

  @override
  int get hashCode => Object.hash(start, end, type);
}

/// Video format / HDR tier reported by the decoder.
enum VideoFormat {
  /// Standard dynamic range.
  sdr,

  /// High dynamic range (generic).
  hdr,

  /// HDR10 static metadata.
  hdr10,

  /// HDR10+ dynamic metadata.
  hdr10Plus,

  /// Dolby Vision.
  dolbyVision,

  /// Hybrid Log-Gamma.
  hlg,
}

/// Audio format reported by the decoder.
enum AudioFormat {
  /// Standard stereo/surround.
  standard,

  /// Dolby Digital (AC-3).
  dolbyDigital,

  /// Dolby Digital Plus (E-AC-3).
  dolbyDigitalPlus,

  /// Dolby Atmos object audio.
  dolbyAtmos,

  /// DTS.
  dts,

  /// DTS:X object audio.
  dtsX,

  /// TrueHD.
  trueHd,
}

/// Playback status.
enum PlaybackStatus {
  /// Player is created but no media loaded.
  idle,

  /// Media is loading/buffering.
  buffering,

  /// Actively playing.
  playing,

  /// Paused by user.
  paused,

  /// Playback error occurred.
  error,
}

/// Audio track info.
@immutable
class AudioTrack {
  const AudioTrack({required this.id, required this.title, this.language});

  final int id;
  final String title;
  final String? language;
}

/// Subtitle track info.
@immutable
class SubtitleTrack {
  const SubtitleTrack({required this.id, required this.title, this.language});

  final int id;
  final String title;
  final String? language;
}

/// Immutable snapshot of the player's current state.
@immutable
class PlaybackState {
  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.speed = 1.0,
    this.isFullscreen = false,
    this.isLive = false,
    this.aspectRatioLabel = 'Auto',
    this.channelName,
    this.channelLogoUrl,
    this.currentProgram,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.selectedAudioTrackId,
    this.selectedSubtitleTrackId,
    this.selectedSecondarySubtitleTrackId,
    this.errorMessage,
    this.retryCount = 0,
    this.sleepTimerRemaining,
    this.videoFormat,
    this.audioFormat,
    this.is4k = false,
    this.skipSegments = const [],
  });

  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final double volume;
  final bool isMuted;
  final double speed;
  final bool isFullscreen;

  /// Whether the current stream is live (vs VOD).
  final bool isLive;

  /// Current aspect ratio label (Auto, 16:9, 4:3, Fill).
  final String aspectRatioLabel;

  /// Current channel metadata for OSD display.
  final String? channelName;
  final String? channelLogoUrl;
  final String? currentProgram;

  /// Available tracks.
  final List<AudioTrack> audioTracks;
  final List<SubtitleTrack> subtitleTracks;
  final int? selectedAudioTrackId;
  final int? selectedSubtitleTrackId;

  /// Secondary subtitle track for dual-subtitle display.
  ///
  /// When non-null and different from [selectedSubtitleTrackId],
  /// a second subtitle overlay is rendered via mpv `secondary-sid`.
  final int? selectedSecondarySubtitleTrackId;

  /// Error details when [status] is [PlaybackStatus.error].
  final String? errorMessage;

  /// Current retry attempt number (0 if not retrying).
  final int retryCount;

  /// Remaining duration of the sleep timer, or `null` if
  /// no sleep timer is active.
  final Duration? sleepTimerRemaining;

  /// Video HDR/format tier detected by the decoder.
  /// `null` means unknown / not yet detected.
  final VideoFormat? videoFormat;

  /// Audio format detected by the decoder.
  /// `null` means unknown / not yet detected.
  final AudioFormat? audioFormat;

  /// Whether the stream resolution is ≥ 2160p (4 K).
  final bool is4k;

  /// Skip segments for this content (intro, recap, credits).
  ///
  /// Empty for live streams and content without segment data.
  final List<SkipSegment> skipSegments;

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isBuffering => status == PlaybackStatus.buffering;
  bool get hasError => status == PlaybackStatus.error;

  /// Buffer latency for live streams (buffered - position).
  /// Returns [Duration.zero] for VOD or when no buffer data.
  Duration get bufferLatency {
    if (!isLive) return Duration.zero;
    final diff = bufferedPosition - position;
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Progress ratio (0.0 – 1.0) for live streams this is 0.
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Buffer progress ratio (0.0 – 1.0).
  double get bufferProgress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (bufferedPosition.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  /// Whether a sleep timer is currently active.
  bool get hasSleepTimer =>
      sleepTimerRemaining != null && sleepTimerRemaining! > Duration.zero;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackState &&
          status == other.status &&
          position == other.position &&
          duration == other.duration &&
          bufferedPosition == other.bufferedPosition &&
          volume == other.volume &&
          isMuted == other.isMuted &&
          speed == other.speed &&
          isFullscreen == other.isFullscreen &&
          isLive == other.isLive &&
          aspectRatioLabel == other.aspectRatioLabel &&
          channelName == other.channelName &&
          channelLogoUrl == other.channelLogoUrl &&
          currentProgram == other.currentProgram &&
          selectedAudioTrackId == other.selectedAudioTrackId &&
          selectedSubtitleTrackId == other.selectedSubtitleTrackId &&
          selectedSecondarySubtitleTrackId ==
              other.selectedSecondarySubtitleTrackId &&
          errorMessage == other.errorMessage &&
          retryCount == other.retryCount &&
          sleepTimerRemaining == other.sleepTimerRemaining &&
          videoFormat == other.videoFormat &&
          audioFormat == other.audioFormat &&
          is4k == other.is4k &&
          identical(audioTracks, other.audioTracks) &&
          identical(subtitleTracks, other.subtitleTracks) &&
          identical(skipSegments, other.skipSegments);

  @override
  int get hashCode => Object.hashAll([
    status,
    position,
    duration,
    bufferedPosition,
    volume,
    isMuted,
    speed,
    isFullscreen,
    isLive,
    aspectRatioLabel,
    channelName,
    channelLogoUrl,
    currentProgram,
    selectedAudioTrackId,
    selectedSubtitleTrackId,
    selectedSecondarySubtitleTrackId,
    errorMessage,
    retryCount,
    sleepTimerRemaining,
    videoFormat,
    audioFormat,
    is4k,
    audioTracks,
    subtitleTracks,
    skipSegments,
  ]);

  PlaybackState copyWith({
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    double? volume,
    bool? isMuted,
    double? speed,
    bool? isFullscreen,
    bool? isLive,
    String? aspectRatioLabel,
    String? channelName,
    String? channelLogoUrl,
    String? currentProgram,
    List<AudioTrack>? audioTracks,
    List<SubtitleTrack>? subtitleTracks,
    int? selectedAudioTrackId,
    int? selectedSubtitleTrackId,
    int? selectedSecondarySubtitleTrackId,
    bool clearSecondarySubtitle = false,
    String? errorMessage,
    int? retryCount,
    bool clearError = false,
    Duration? sleepTimerRemaining,
    bool clearSleepTimer = false,
    VideoFormat? videoFormat,
    bool clearVideoFormat = false,
    AudioFormat? audioFormat,
    bool clearAudioFormat = false,
    bool? is4k,
    List<SkipSegment>? skipSegments,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      speed: speed ?? this.speed,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      isLive: isLive ?? this.isLive,
      aspectRatioLabel: aspectRatioLabel ?? this.aspectRatioLabel,
      channelName: channelName ?? this.channelName,
      channelLogoUrl: channelLogoUrl ?? this.channelLogoUrl,
      currentProgram: currentProgram ?? this.currentProgram,
      audioTracks: audioTracks ?? this.audioTracks,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      selectedAudioTrackId: selectedAudioTrackId ?? this.selectedAudioTrackId,
      selectedSubtitleTrackId:
          selectedSubtitleTrackId ?? this.selectedSubtitleTrackId,
      selectedSecondarySubtitleTrackId:
          clearSecondarySubtitle
              ? null
              : (selectedSecondarySubtitleTrackId ??
                  this.selectedSecondarySubtitleTrackId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      retryCount: retryCount ?? this.retryCount,
      sleepTimerRemaining:
          clearSleepTimer
              ? null
              : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      videoFormat: clearVideoFormat ? null : (videoFormat ?? this.videoFormat),
      audioFormat: clearAudioFormat ? null : (audioFormat ?? this.audioFormat),
      is4k: is4k ?? this.is4k,
      skipSegments: skipSegments ?? this.skipSegments,
    );
  }
}
