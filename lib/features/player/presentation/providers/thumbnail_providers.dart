import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import 'player_service_providers.dart';
import '../../domain/entities/thumbnail_sprite.dart';

/// Provider for [ThumbnailService].
final thumbnailServiceProvider = Provider<ThumbnailService>((ref) {
  final service = ThumbnailService(
    backend: ref.read(crispyBackendProvider),
    dio: ref.watch(dioProvider),
  );
  ref.onDispose(() => service.clearCache());
  return service;
});

/// Parameters for thumbnail loading.
class ThumbnailParams {
  const ThumbnailParams({required this.streamUrl, required this.duration});

  final String streamUrl;
  final Duration duration;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ThumbnailParams) return false;
    return streamUrl == other.streamUrl && duration == other.duration;
  }

  @override
  int get hashCode => Object.hash(streamUrl, duration);
}

/// Provider for thumbnail data (VTT sprite or BIF trickplay).
///
/// Returns null if thumbnails are unavailable or loading failed.
final thumbnailSpriteProvider = FutureProvider.family
    .autoDispose<ThumbnailSource?, ThumbnailParams>((ref, params) async {
      // Don't load thumbnails for live streams (no duration)
      if (params.duration == Duration.zero) {
        return null;
      }

      final service = ref.watch(thumbnailServiceProvider);
      return service.loadThumbnails(
        streamUrl: params.streamUrl,
        duration: params.duration,
      );
    });

/// Notifier for current hover X coordinate on seek bar.
class SeekBarHoverXNotifier extends Notifier<double?> {
  @override
  double? build() => null;

  void setX(double? x) {
    state = x;
  }
}

/// Provider for hover X coordinate.
final seekBarHoverXProvider = NotifierProvider<SeekBarHoverXNotifier, double?>(
  SeekBarHoverXNotifier.new,
);

/// Notifier for seek bar hover state.
///
/// Manages the hover position and X coordinate.
class SeekBarHoverNotifier extends Notifier<Duration?> {
  @override
  Duration? build() => null;

  /// Updates the hover position based on seek bar coordinates.
  ///
  /// [xPosition] - The X coordinate of the hover position.
  /// [seekBarWidth] - The total width of the seek bar.
  /// [duration] - The total video duration.
  void updateHover({
    required double xPosition,
    required double seekBarWidth,
    required Duration duration,
  }) {
    if (seekBarWidth <= 0 || duration == Duration.zero) {
      state = null;
      return;
    }

    final progress = (xPosition / seekBarWidth).clamp(0.0, 1.0);
    final position = Duration(
      milliseconds: (progress * duration.inMilliseconds).round(),
    );

    state = position;
    ref.read(seekBarHoverXProvider.notifier).setX(xPosition);
  }

  /// Clears the hover state (mouse exited seek bar).
  void clearHover() {
    state = null;
    ref.read(seekBarHoverXProvider.notifier).setX(null);
  }
}

/// Provider for [SeekBarHoverNotifier].
final seekBarHoverNotifierProvider =
    NotifierProvider<SeekBarHoverNotifier, Duration?>(SeekBarHoverNotifier.new);

/// Current hover position on seek bar.
///
/// Null when not hovering over the seek bar.
final seekBarHoverPositionProvider = Provider<Duration?>((ref) {
  return ref.watch(seekBarHoverNotifierProvider);
});

/// Whether the seek bar is currently being hovered.
final isSeekBarHoveredProvider = Provider<bool>((ref) {
  return ref.watch(seekBarHoverPositionProvider) != null;
});

/// Thumbnail region for the current hover position.
///
/// Returns null if:
/// - Not hovering over seek bar
/// - Thumbnails not available
/// - No thumbnail for current position
final currentThumbnailRegionProvider = Provider.family
    .autoDispose<ThumbnailRegion?, ThumbnailParams>((ref, params) {
      final hoverPosition = ref.watch(seekBarHoverPositionProvider);
      if (hoverPosition == null) return null;

      final spriteAsync = ref.watch(thumbnailSpriteProvider(params));
      final sprite = spriteAsync.value;
      if (sprite == null) return null;

      return sprite.getRegionAt(hoverPosition);
    });
