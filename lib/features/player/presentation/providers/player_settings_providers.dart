import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../data/afr_service.dart';
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

/// AFR service provider that automatically syncs with settings.
final afrServiceProvider = Provider<AfrService>((ref) {
  final service = AfrService();
  final enabled = ref.watch(afrEnabledProvider);

  // Sync service state with settings
  service.setEnabled(enabled);

  ref.onDispose(() => service.dispose());
  return service;
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

/// Provider that syncs audio configuration to the PlayerService.
final audioSyncProvider = Provider<void>((ref) {
  final audioOutput = ref.watch(audioOutputProvider);
  final passthroughEnabled = ref.watch(audioPassthroughEnabledProvider);
  final passthroughCodecs = ref.watch(audioPassthroughCodecsProvider);
  final playerService = ref.watch(playerServiceProvider);

  // Apply audio output driver.
  playerService.setAudioOutput(audioOutput);

  // Apply passthrough settings.
  playerService.setAudioPassthrough(passthroughEnabled, passthroughCodecs);
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

/// Deinterlace mode for live TV streams.
///
/// Values: `'off'` (disabled, default) or `'auto'`
/// (media_kit auto-detect).
final deinterlaceModeProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.deinterlaceMode ?? 'off';
});

/// Syncs the deinterlace mode to the [PlayerService].
final deinterlaceSyncProvider = Provider<void>((ref) {
  final mode = ref.watch(deinterlaceModeProvider);
  final playerService = ref.watch(playerServiceProvider);

  // Apply to PlayerService
  playerService.setDeinterlace(mode);
});

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
