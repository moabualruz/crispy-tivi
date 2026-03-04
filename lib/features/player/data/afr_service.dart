import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'afr_helper.dart';

/// Provider for AFR Service.
final afrServiceProvider = Provider<AfrService>((ref) {
  return AfrService();
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
  final _helper = AfrHelper();
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
  void monitor(Player player) {
    _trackSubscription?.cancel();
    _trackSubscription = player.stream.tracks.listen((tracks) async {
      if (!_isEnabled) return;

      final videoTrack = tracks.video.firstOrNull;
      if (videoTrack == null) return;

      // Extract FPS from libmpv using NativePlayer
      final fps = await _extractFps(player);
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

  /// Extracts video FPS from the player using libmpv properties.
  ///
  /// Tries multiple properties in order of preference:
  /// 1. `estimated-vf-fps` - Most accurate, post-filter chain FPS
  /// 2. `container-fps` - Container-reported FPS
  Future<double?> _extractFps(Player player) async {
    // Skip on web or unsupported platforms
    if (kIsWeb) return null;

    try {
      final nativePlayer = player.platform;
      if (nativePlayer == null) return null;

      // Use dynamic to access NativePlayer methods
      // This avoids direct dependency on platform-specific types
      final dynamic native = nativePlayer;

      // Try estimated-vf-fps first (most accurate)
      try {
        final estimated = await native.getProperty('estimated-vf-fps');
        final fps = double.tryParse(estimated ?? '');
        if (fps != null && fps > 0) {
          debugPrint('AFR: Got estimated-vf-fps: $fps');
          return fps;
        }
      } catch (e) {
        debugPrint('AFR: estimated-vf-fps not available: $e');
      }

      // Fall back to container-fps
      try {
        final container = await native.getProperty('container-fps');
        final fps = double.tryParse(container ?? '');
        if (fps != null && fps > 0) {
          debugPrint('AFR: Got container-fps: $fps');
          return fps;
        }
      } catch (e) {
        debugPrint('AFR: container-fps not available: $e');
      }

      return null;
    } catch (e) {
      debugPrint('AFR: FPS extraction failed: $e');
      return null;
    }
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
