import 'package:flutter/foundation.dart';

/// Abstract interface for thumbnail data sources.
///
/// Both VTT sprite sheets and BIF trickplay files implement
/// this to provide format-agnostic thumbnail lookup.
abstract class ThumbnailSource {
  /// Gets the thumbnail region for a given video position.
  ThumbnailRegion? getRegionAt(Duration position);
}

/// Represents a thumbnail sprite sheet with timing data.
///
/// Sprite sheets contain multiple thumbnails in a grid layout,
/// with a VTT file mapping timestamps to sprite positions.
@immutable
class ThumbnailSprite implements ThumbnailSource {
  const ThumbnailSprite({
    required this.imageUrl,
    required this.columns,
    required this.rows,
    required this.thumbWidth,
    required this.thumbHeight,
    required this.cues,
  });

  /// URL to the sprite sheet image.
  final String imageUrl;

  /// Number of columns in the sprite grid.
  final int columns;

  /// Number of rows in the sprite grid.
  final int rows;

  /// Width of each thumbnail in pixels.
  final int thumbWidth;

  /// Height of each thumbnail in pixels.
  final int thumbHeight;

  /// Time-to-position mappings for each thumbnail.
  final List<ThumbnailCue> cues;

  /// Total number of thumbnails in the sprite sheet.
  int get thumbnailCount => columns * rows;

  /// Gets the sprite region for a given position.
  ///
  /// Returns null if the position is not within any cue range.
  @override
  ThumbnailRegion? getRegionAt(Duration position) {
    for (final cue in cues) {
      if (position >= cue.start && position < cue.end) {
        return ThumbnailRegion(
          imageUrl: imageUrl,
          x: cue.x,
          y: cue.y,
          width: thumbWidth,
          height: thumbHeight,
        );
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ThumbnailSprite) return false;
    return imageUrl == other.imageUrl &&
        columns == other.columns &&
        rows == other.rows &&
        thumbWidth == other.thumbWidth &&
        thumbHeight == other.thumbHeight;
  }

  @override
  int get hashCode =>
      Object.hash(imageUrl, columns, rows, thumbWidth, thumbHeight);
}

/// A single cue entry mapping a time range to sprite coordinates.
@immutable
class ThumbnailCue {
  const ThumbnailCue({
    required this.start,
    required this.end,
    required this.x,
    required this.y,
  });

  /// Start time of this thumbnail cue.
  final Duration start;

  /// End time of this thumbnail cue.
  final Duration end;

  /// X offset in the sprite sheet (pixels from left).
  final int x;

  /// Y offset in the sprite sheet (pixels from top).
  final int y;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ThumbnailCue) return false;
    return start == other.start &&
        end == other.end &&
        x == other.x &&
        y == other.y;
  }

  @override
  int get hashCode => Object.hash(start, end, x, y);
}

/// Represents a region within a sprite sheet or a standalone
/// thumbnail image for rendering.
@immutable
class ThumbnailRegion {
  const ThumbnailRegion({
    this.imageUrl = '',
    this.imageBytes,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// URL to the sprite sheet image (VTT sprites).
  final String imageUrl;

  /// Raw JPEG bytes for standalone thumbnails (BIF).
  final Uint8List? imageBytes;

  /// X offset within the sprite sheet (0 for BIF).
  final int x;

  /// Y offset within the sprite sheet (0 for BIF).
  final int y;

  /// Width of the thumbnail region.
  final int width;

  /// Height of the thumbnail region.
  final int height;

  /// Whether this region uses raw image bytes (BIF format).
  bool get isBifThumbnail => imageBytes != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ThumbnailRegion) return false;
    return imageUrl == other.imageUrl &&
        x == other.x &&
        y == other.y &&
        width == other.width &&
        height == other.height;
  }

  @override
  int get hashCode => Object.hash(imageUrl, x, y, width, height);
}
