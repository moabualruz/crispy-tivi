import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../data/segment_skip_codec.dart';
import '../../domain/segment_skip_config.dart';
import '../../domain/entities/gpu_info.dart';
import '../../domain/entities/hardware_decoder.dart';
import '../../domain/entities/stream_profile.dart';
import '../../../dvr/domain/entities/recording_profile.dart';
import 'player_providers.dart';
import 'upscale_providers.dart';

/// Valid seek step values in seconds.
const List<int> kSeekStepOptions = [5, 10, 15, 20, 30];

// ─────────────────────────────────────────────────────────────
//  AFR (Automatic Frame Rate matching)
// ─────────────────────────────────────────────────────────────

/// Whether AFR is globally enabled (from settings).
final afrEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.afrEnabled ?? false;
});

/// Whether AFR should apply to Live TV content.
final afrLiveTvProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.afrLiveTv ?? true;
});

/// Whether AFR should apply to VOD content.
final afrVodProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.afrVod ?? true;
});

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
//  Hardware Decoder (hwdec)
// ─────────────────────────────────────────────────────────────

/// Current hardware decoder mode from settings.
final hwdecModeProvider = Provider<HardwareDecoder>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  final modeName = settings.value?.config.player.hwdecMode ?? 'auto';

  return HardwareDecoder.fromMpvValue(modeName);
});

/// Provider that syncs hwdec mode to the PlayerService.
final hwdecSyncProvider = Provider<void>((ref) {
  final hwdec = ref.watch(hwdecModeProvider);
  final playerService = ref.watch(playerServiceProvider);

  // Apply hwdec mode to the player service.
  playerService.setHwdecMode(hwdec.mpvValue);
});

// ─────────────────────────────────────────────────────────────
//  Recording Profile (DVR Quality Selection)
// ─────────────────────────────────────────────────────────────

/// Current recording profile from settings.
final recordingProfileProvider = Provider<RecordingProfile>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  final profileName =
      settings.value?.config.player.recordingProfile ?? 'original';

  return RecordingProfile.values.firstWhere(
    (p) => p.name == profileName,
    orElse: () => RecordingProfile.original,
  );
});

// ─────────────────────────────────────────────────────────────
//  EPG Timezone
// ─────────────────────────────────────────────────────────────

/// Current EPG timezone setting from config.
final epgTimezoneProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.epgTimezone ?? 'system';
});

// ─────────────────────────────────────────────────────────────
//  Audio Output & Passthrough
// ─────────────────────────────────────────────────────────────

/// Current audio output driver from settings.
final audioOutputProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.audioOutput ?? 'auto';
});

/// Whether audio passthrough is enabled from settings.
final audioPassthroughEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.audioPassthroughEnabled ?? false;
});

/// List of passthrough codecs from settings.
final audioPassthroughCodecsProvider = Provider<List<String>>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.audioPassthroughCodecs ??
      const ['ac3', 'dts'];
});

/// Whether EBU R128 loudness normalization is enabled.
final loudnessNormalizationProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.loudnessNormalization ?? true;
});

/// Whether surround-to-stereo downmix is enabled.
final stereoDownmixProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.stereoDownmix ?? false;
});

/// Maximum volume percentage from settings (100–300).
final maxVolumeProvider = Provider<int>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  final raw = settings.value?.config.player.maxVolume ?? 100;
  return raw.clamp(100, 300);
});

/// Runtime audio passthrough that can be toggled via the OSD.
///
/// Initializes from persistent settings but allows override during
/// the current playback session.
class RuntimePassthroughNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(audioPassthroughEnabledProvider);

  /// Toggle passthrough on/off for the current session.
  void toggle() {
    state = !state;
  }
}

/// Current runtime passthrough state (toggleable from OSD).
final runtimePassthroughProvider =
    NotifierProvider<RuntimePassthroughNotifier, bool>(
      RuntimePassthroughNotifier.new,
    );

/// Provider that syncs audio configuration to the PlayerService.
final audioSyncProvider = Provider<void>((ref) {
  final audioOutput = ref.watch(audioOutputProvider);
  final passthroughEnabled = ref.watch(runtimePassthroughProvider);
  final passthroughCodecs = ref.watch(audioPassthroughCodecsProvider);
  final loudness = ref.watch(loudnessNormalizationProvider);
  final downmix = ref.watch(stereoDownmixProvider);
  final maxVolume = ref.watch(maxVolumeProvider);
  final playerService = ref.watch(playerServiceProvider);

  // Apply audio output driver.
  playerService.setAudioOutput(audioOutput);

  // Apply passthrough settings.
  playerService.setAudioPassthrough(passthroughEnabled, passthroughCodecs);

  // Apply loudness normalization and stereo downmix.
  playerService.setLoudnessNormalization(loudness);
  playerService.setStereoDownmix(downmix);

  // Apply max volume.
  playerService.setMaxVolume(maxVolume);
});

// ───────────────────────────────────────────────────────
//  Video Upscaling
// ───────────────────────────────────────────────────────

/// Syncs upscaling settings to the [PlayerService].
///
/// Watches [upscaleModeProvider],
/// [upscaleQualityProvider], and [gpuInfoProvider],
/// then pushes changes to
/// [PlayerService.setUpscaleConfig].
final upscaleSyncProvider = Provider<void>((ref) {
  final mode = ref.watch(upscaleModeProvider);
  final quality = ref.watch(upscaleQualityProvider);
  final gpuAsync = ref.watch(gpuInfoProvider);
  final playerService = ref.watch(playerServiceProvider);

  final gpu = gpuAsync.value ?? GpuInfo.unknown;

  playerService.setUpscaleConfig(mode: mode, quality: quality, gpu: gpu);
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
//  Always-on-Top (Desktop: Windows + Linux)
// ─────────────────────────────────────────────────────────────

/// Runtime always-on-top state for the player window.
///
/// Tracked as a Notifier so the OSD menu can show the current
/// state and the T keyboard shortcut can toggle it.
class AlwaysOnTopNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Toggle the always-on-top state.
  void toggle() => state = !state;

  /// Set the always-on-top state explicitly.
  void set(bool value) => state = value;
}

/// Current always-on-top state (toggleable from OSD / T key).
final alwaysOnTopProvider = NotifierProvider<AlwaysOnTopNotifier, bool>(
  AlwaysOnTopNotifier.new,
);

// ─────────────────────────────────────────────────────────────
//  Screen Brightness (Mobile: Android + iOS)
// ─────────────────────────────────────────────────────────────

/// Runtime screen brightness override (null = system default).
///
/// When non-null, the player sets system brightness to this
/// value (0.0–1.0). On player exit, reset to null and call
/// [ScreenBrightness.resetApplicationScreenBrightness].
class ScreenBrightnessNotifier extends Notifier<double?> {
  @override
  double? build() => null;

  /// Set brightness override (0.0–1.0).
  void setBrightness(double value) => state = value.clamp(0.0, 1.0);

  /// Reset to system default.
  void resetToSystem() => state = null;
}

/// Current screen brightness override (null = system default).
final screenBrightnessProvider =
    NotifierProvider<ScreenBrightnessNotifier, double?>(
      ScreenBrightnessNotifier.new,
    );

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
