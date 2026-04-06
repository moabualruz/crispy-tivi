import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks active video surfaces and enforces the
/// single-active-surface invariant.
///
/// Only one video surface may be active at a time. Attempting
/// to activate a second surface throws [StateError].
class VideoSurfaceManager {
  String? _activeSurfaceId;

  /// Register a surface as active.
  ///
  /// Throws [StateError] if another surface is already active.
  void activateSurface(String surfaceId) {
    if (_activeSurfaceId != null && _activeSurfaceId != surfaceId) {
      throw StateError(
        'Cannot activate surface "$surfaceId" — '
        'surface "$_activeSurfaceId" is already active',
      );
    }
    _activeSurfaceId = surfaceId;
  }

  /// Deactivate a surface.
  ///
  /// No-op if the surface is not currently active.
  void deactivateSurface(String surfaceId) {
    if (_activeSurfaceId == surfaceId) {
      _activeSurfaceId = null;
    }
  }

  /// Whether any surface is currently active.
  bool get hasActiveSurface => _activeSurfaceId != null;

  /// The currently active surface ID, or `null`.
  String? get activeSurfaceId => _activeSurfaceId;

  /// Reset all surfaces (used in dispose cascade).
  void reset() {
    _activeSurfaceId = null;
  }
}

/// Provides a singleton [VideoSurfaceManager] for the app.
final videoSurfaceManagerProvider = Provider<VideoSurfaceManager>((ref) {
  return VideoSurfaceManager();
});
