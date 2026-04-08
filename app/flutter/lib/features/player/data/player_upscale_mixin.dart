part of 'player_service.dart';

/// Video upscaling configuration and application.
///
/// Applies GPU-aware upscaling via [UpscaleManager]
/// when video resolution is detected or changes.
/// On web, delegates to [web_upscale_bridge] JS
/// interop pipeline. Settings are synced from
/// providers via [setUpscaleConfig].
mixin PlayerUpscaleMixin on PlayerServiceBase {
  /// The currently active upscale tier, or `null` if
  /// playback is unprocessed.
  int? get activeUpscaleTier => _activeUpscaleTier;

  /// Updates upscale configuration and re-applies if
  /// currently playing.
  void setUpscaleConfig({
    UpscaleMode? mode,
    UpscaleQuality? quality,
    GpuInfo? gpu,
  }) {
    var changed = false;
    if (mode != null && mode != _upscaleMode) {
      _upscaleMode = mode;
      changed = true;
    }
    if (quality != null && quality != _upscaleQuality) {
      _upscaleQuality = quality;
      changed = true;
    }
    if (gpu != null) {
      _gpuInfo = gpu;
      changed = true;
    }

    if (changed) {
      debugPrint(
        'PlayerUpscale: config updated — '
        'mode=${_upscaleMode.value}, '
        'quality=${_upscaleQuality.value}, '
        'gpu=${_gpuInfo.name}',
      );
      // Re-apply if currently playing (native) or
      // web bridge is active (web).
      if (_player.isPlaying || _webBridge != null) {
        applyUpscale();
      }
    }
  }

  /// Applies upscaling based on current config.
  ///
  /// On native: called when playback starts or video
  /// resolution changes. Uses [UpscaleManager]
  /// fallback chain.
  ///
  /// On web: calls the JS upscaler via
  /// [web_upscale_bridge]. The JS handles video
  /// element lookup, metadata timing, and the
  /// WebGL 2 pipeline.
  ///
  /// Overrides the no-op stub in [PlayerServiceBase]
  /// so other mixins can call it.
  @override
  Future<void> applyUpscale() async {
    if (kIsWeb) {
      await _applyWebUpscale();
      return;
    }
    try {
      final tier = await _upscaleManager.applyUpscaling(
        _player,
        _upscaleMode,
        _upscaleQuality,
        _gpuInfo,
      );
      _activeUpscaleTier = tier;
      debugPrint(
        'PlayerUpscale: active tier = '
        '${tier ?? "unprocessed"}',
      );
    } catch (e) {
      debugPrint(
        'PlayerUpscale: applyUpscaling '
        'failed: $e',
      );
      _activeUpscaleTier = null;
    }
  }

  /// Web-specific upscaling via JS interop.
  Future<void> _applyWebUpscale() async {
    if (_upscaleMode == UpscaleMode.off) {
      await removeWebUpscaling();
      _activeUpscaleTier = null;
      debugPrint('PlayerUpscale: web — off');
      return;
    }
    try {
      final ok = await applyWebUpscaling(
        scaleFactor: 1.0, // JS calculates actual
        quality: _upscaleQuality.value,
      );
      _activeUpscaleTier = ok ? 3 : null;
      debugPrint(
        'PlayerUpscale: web — '
        '${ok ? "active" : "unavailable"}',
      );
    } catch (e) {
      debugPrint('PlayerUpscale: web failed: $e');
      _activeUpscaleTier = null;
    }
  }

  /// Removes all upscaling filters.
  Future<void> removeUpscale() async {
    if (kIsWeb) {
      await removeWebUpscaling();
      _activeUpscaleTier = null;
      return;
    }
    await _upscaleManager.removeUpscaling(_player);
    _activeUpscaleTier = null;
  }
}
