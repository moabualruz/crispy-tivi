import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../data/segment_skip_codec.dart';
import '../../domain/segment_skip_config.dart';
import '../../domain/entities/stream_profile.dart';
import 'player_providers.dart';

// ─────────────────────────────────────────────────────────────
//  Stream Profile (Quality Selection)
// ─────────────────────────────────────────────────────────────

/// Current stream profile from settings.
final streamProfileProvider = Provider<StreamProfile>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  final profileName = settings.value?.config.player.streamProfile ?? 'auto';

  return StreamProfile.values.firstWhere(
    (p) => p.name == profileName,
    orElse: () => StreamProfile.auto,
  );
});

/// Runtime stream profile that can be changed via the OSD quality picker.
///
/// Initializes from persistent settings but allows override during
/// the current playback session (mirrors [RuntimeDeinterlaceNotifier]).
class RuntimeStreamProfileNotifier extends Notifier<StreamProfile> {
  @override
  StreamProfile build() => ref.watch(streamProfileProvider);

  /// Set a new profile for the current session.
  void set(StreamProfile profile) {
    state = profile;
  }
}

/// Current runtime stream profile (changeable from OSD).
final runtimeStreamProfileProvider =
    NotifierProvider<RuntimeStreamProfileNotifier, StreamProfile>(
      RuntimeStreamProfileNotifier.new,
    );

/// Syncs the stream profile to the [PlayerService].
final streamProfileSyncProvider = Provider<void>((ref) {
  final profile = ref.watch(runtimeStreamProfileProvider);
  final playerService = ref.watch(playerServiceProvider);
  playerService.setStreamProfile(profile);
});

// ─────────────────────────────────────────────────────────────
//  Skip Buttons (FE-PS-03)
// ─────────────────────────────────────────────────────────────

/// Whether Skip Intro / Skip Credits overlay buttons are
/// enabled for VOD playback.
///
/// When `false`, the [SkipSegmentButton] is suppressed
/// even if the content has skip segment data.
final showSkipButtonsProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.showSkipButtons ?? true;
});

// ─────────────────────────────────────────────────────────────
//  Segment Skip Config (per-type skip behavior)
// ─────────────────────────────────────────────────────────────

/// Decoded per-type segment skip configuration.
///
/// Maps each [SegmentType] to its [SegmentSkipMode] from
/// persistent settings. Returns [defaultSegmentSkipConfig]
/// when no custom config is saved.
final segmentSkipConfigProvider = Provider<Map<SegmentType, SegmentSkipMode>>((
  ref,
) {
  final settings = ref.watch(settingsNotifierProvider);
  final json = settings.value?.config.player.segmentSkipConfig;
  return decodeSegmentSkipConfig(json);
});

/// Current next-up overlay trigger mode.
///
/// Values: [NextUpMode.off], [NextUpMode.static], [NextUpMode.smart].
final nextUpModeProvider = Provider<NextUpMode>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  final name = settings.value?.config.player.nextUpMode;
  return parseNextUpMode(name);
});

// ─────────────────────────────────────────────────────────────
//  Seek Step (PS-09)
// ─────────────────────────────────────────────────────────────

/// User-configured seek step in seconds.
///
/// Default: 10 s. Valid values: 5, 10, 15, 20, 30.
/// Persisted via [PlayerConfig.seekStepSeconds].
final seekStepSecondsProvider = Provider<int>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  final raw = settings.value?.config.player.seekStepSeconds ?? 10;
  // Clamp to valid options; fall back to 10 s if stored value is
  // outside the allowed set (e.g. migrated from old config).
  return kSeekStepOptions.contains(raw) ? raw : 10;
});

// ─────────────────────────────────────────────────────────────
//  Deinterlace Mode (PS-14)
// ─────────────────────────────────────────────────────────────

/// Deinterlace mode from persistent settings.
///
/// Values: `'off'` (disabled, default), `'auto'`, or `'on'`.
final deinterlaceModeProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.deinterlaceMode ?? 'off';
});

/// Valid deinterlace modes for cycling.
const _deinterlaceModes = ['auto', 'off', 'on'];

/// Runtime deinterlace mode that can be cycled via the OSD.
///
/// Initializes from persistent settings but allows override during
/// the current playback session.
class RuntimeDeinterlaceNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(deinterlaceModeProvider);

  /// Cycle to the next mode: auto → off → on → auto.
  void cycle() {
    final idx = _deinterlaceModes.indexOf(state);
    state = _deinterlaceModes[(idx + 1) % _deinterlaceModes.length];
  }
}

/// Current runtime deinterlace mode (cycleable from OSD).
final runtimeDeinterlaceProvider =
    NotifierProvider<RuntimeDeinterlaceNotifier, String>(
      RuntimeDeinterlaceNotifier.new,
    );

/// Syncs the deinterlace mode to the [PlayerService].
final deinterlaceSyncProvider = Provider<void>((ref) {
  final mode = ref.watch(runtimeDeinterlaceProvider);
  final playerService = ref.watch(playerServiceProvider);

  // Apply to PlayerService
  playerService.setDeinterlace(mode);
});

// ─────────────────────────────────────────────────────────────
//  Finish Time Estimate (VOD seek bar)
// ─────────────────────────────────────────────────────────────

/// Whether to show a wall-clock finish time next to the
/// remaining duration on the VOD seek bar. Speed-aware.
final showFinishTimeProvider = Provider<bool>((_) => true);

// ─────────────────────────────────────────────────────────────
//  Persistent Playback Speed (PS-17)
// ─────────────────────────────────────────────────────────────

/// Retains the last-used playback speed across sessions.
///
/// Updated whenever the user changes speed during playback.
/// Applied on [PlaybackSessionNotifier.startPlayback] so VOD
/// resumes at the speed the user prefers.
///
/// Default: 1.0 (normal speed).
class LastPlaybackSpeedNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  /// Persist a new speed value.
  void setSpeed(double speed) {
    state = speed.clamp(0.25, 4.0);
  }

  /// Reset to normal speed (e.g. for live TV).
  void reset() {
    state = 1.0;
  }
}

/// Provider for the last-used playback speed.
///
/// Screens and services read this to restore speed on
/// new VOD sessions. Call [LastPlaybackSpeedNotifier.setSpeed]
/// whenever playback speed changes.
final lastPlaybackSpeedProvider =
    NotifierProvider<LastPlaybackSpeedNotifier, double>(
      LastPlaybackSpeedNotifier.new,
    );
