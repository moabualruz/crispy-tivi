import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../domain/entities/gpu_info.dart';
import '../../domain/entities/hardware_decoder.dart';
import '../../../dvr/domain/entities/recording_profile.dart';
import 'player_providers.dart';
import 'upscale_providers.dart';
import 'player_settings_advanced_providers.dart';

export 'player_settings_advanced_providers.dart';

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
