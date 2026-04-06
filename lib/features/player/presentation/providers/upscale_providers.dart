import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import 'player_service_providers.dart';
import '../../data/gpu_json_codec.dart';
import '../../data/upscale_manager.dart';
import '../../domain/entities/gpu_info.dart';
import '../../domain/entities/upscale_mode.dart';
import '../../domain/entities/upscale_quality.dart';

// ───────────────────────────────────────────────────────
//  Video Upscaling Providers
// ───────────────────────────────────────────────────────

/// Global upscaling master switch.
///
/// When `false` (default), all upscaling is bypassed
/// and standard bilinear playback is used. This is a
/// global (not per-profile) setting under Experimental.
final upscaleEnabledProvider = Provider.autoDispose<bool>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.value?.config.player.upscaleEnabled ?? false;
});

/// Effective [UpscaleMode] from user settings.
///
/// Returns [UpscaleMode.off] when upscaling is
/// globally disabled, regardless of the saved mode.
/// Defaults to [UpscaleMode.auto] if settings are
/// not yet loaded.
final upscaleModeProvider = Provider.autoDispose<UpscaleMode>((ref) {
  final enabled = ref.watch(upscaleEnabledProvider);
  if (!enabled) return UpscaleMode.off;
  final settings = ref.watch(settingsNotifierProvider);
  final value = settings.value?.config.player.upscaleMode ?? 'auto';
  return UpscaleMode.fromValue(value);
});

/// Current [UpscaleQuality] from user settings.
///
/// Defaults to [UpscaleQuality.balanced] if settings
/// are not yet loaded.
final upscaleQualityProvider = Provider.autoDispose<UpscaleQuality>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  final value = settings.value?.config.player.upscaleQuality ?? 'balanced';
  return UpscaleQuality.fromValue(value);
});

/// Tracks which upscale tier is currently active.
///
/// - `null` = unprocessed (no upscaling applied)
/// - `3` = FSR GLSL
/// - `4` = ewa_lanczossharp / spline36
///
/// See `.ai/docs/project-specs/video_upscaling_spec.md` §3.4 for tier
/// definitions.
final upscaleActiveProvider =
    NotifierProvider.autoDispose<UpscaleActiveNotifier, int?>(
      UpscaleActiveNotifier.new,
    );

/// Notifier for the active upscale tier level.
class UpscaleActiveNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  /// Sets the active tier level.
  void set(int? tier) => state = tier;
}

/// Singleton [UpscaleManager] instance.
///
/// Manages shader extraction, filter application, and
/// the fallback chain. Disposed with the provider.
final upscaleManagerProvider = Provider.autoDispose<UpscaleManager>((ref) {
  return UpscaleManager();
});

/// Cached GPU info, detected once at app startup.
///
/// Returns [GpuInfo.unknown] if detection fails.
final gpuInfoProvider = FutureProvider<GpuInfo>((ref) async {
  try {
    final cache = ref.read(cacheServiceProvider);
    final map = await cache.detectGpuInfo();
    return GpuJsonCodec.fromJson(map);
  } catch (e) {
    debugPrint('gpuInfoProvider: detection failed: $e');
    return GpuInfo.unknown;
  }
});
