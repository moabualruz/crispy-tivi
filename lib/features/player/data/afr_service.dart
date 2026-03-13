import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../domain/crispy_player.dart';
import 'afr_helper.dart';

/// Provider for AFR Service.
final afrServiceProvider = Provider<AfrService>((ref) {
  final backend = ref.watch(crispyBackendProvider);
  final service = AfrService(backend);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Service to handle Auto Frame Rate (AFR) switching.
///
/// Attempts to match the display refresh rate to the video's frame rate.
/// Uses libmpv's `estimated-vf-fps` property for accurate FPS detection.
///
/// Platform support:
/// - Android: Uses [flutter_displaymode] to switch display modes.
/// - Windows/Linux: Planned (xrandr/ChangeDisplaySettings).
/// - Web/macOS/iOS: Not supported.
class AfrService {
  AfrService(CrispyBackend backend) : _helper = AfrHelper(backend);

  final AfrHelper _helper;
  StreamSubscription? _trackSubscription;
  bool _isEnabled = false;
  double? _lastAppliedFps;

  /// Current detected video FPS (null if not detected).
  double? get detectedFps => _lastAppliedFps;

  /// Whether AFR is currently enabled.
  bool get isEnabled => _isEnabled;

  /// Enable or disable AFR.
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _lastAppliedFps = null;
      _helper.restoreMode();
    }
  }

  /// Start monitoring the player for video track changes to apply AFR.
  ///
  /// Listens to video track changes and extracts FPS using libmpv's
  /// `estimated-vf-fps` property for accurate frame rate detection.
  void monitor(CrispyPlayer player) {
    _trackSubscription?.cancel();
    _trackSubscription = player.tracksStream.listen((trackList) async {
      if (!_isEnabled) return;
      if (trackList.audio.isEmpty && trackList.subtitle.isEmpty) return;

      // Extract FPS from engine properties.
      final fps = _extractFps(player);
      if (fps == null || fps <= 0) {
        debugPrint('AFR: Could not detect video FPS');
        return;
      }

      // Avoid re-applying the same FPS
      if (_lastAppliedFps == fps) {
        debugPrint('AFR: FPS unchanged ($fps), skipping mode switch');
        return;
      }

      debugPrint('AFR: Detected video FPS: $fps');
      _lastAppliedFps = fps;
      await _helper.switchToBestMode(fps);
    });
  }

  /// Extracts video FPS from the player using engine properties.
  ///
  /// Tries multiple properties in order of preference:
  /// 1. `estimated-vf-fps` - Most accurate, post-filter chain FPS
  /// 2. `container-fps` - Container-reported FPS
  double? _extractFps(CrispyPlayer player) {
    if (kIsWeb) return null;

    // Try estimated-vf-fps first (most accurate)
    final estimated = player.getProperty('estimated-vf-fps');
    final estFps = estimated != null ? double.tryParse(estimated) : null;
    if (estFps != null && estFps > 0) {
      debugPrint('AFR: Got estimated-vf-fps: $estFps');
      return estFps;
    }

    // Fall back to container-fps
    final container = player.getProperty('container-fps');
    final contFps = container != null ? double.tryParse(container) : null;
    if (contFps != null && contFps > 0) {
      debugPrint('AFR: Got container-fps: $contFps');
      return contFps;
    }

    return null;
  }

  /// Manually trigger AFR for a specific FPS value.
  ///
  /// Useful for testing or when FPS is known externally.
  Future<void> applyFps(double fps) async {
    if (!_isEnabled || fps <= 0) return;

    _lastAppliedFps = fps;
    await _helper.switchToBestMode(fps);
  }

  void dispose() {
    _trackSubscription?.cancel();
    _lastAppliedFps = null;
    _helper.restoreMode();
  }
}
