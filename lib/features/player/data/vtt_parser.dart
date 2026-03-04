import '../../../core/data/crispy_backend.dart';
import '../domain/entities/thumbnail_sprite.dart';

/// Parser for WebVTT thumbnail sprite sheets.
///
/// Delegates parsing to the Rust [CrispyBackend] and
/// converts the result map into [ThumbnailSprite].
class VttParser {
  VttParser(this._backend);

  final CrispyBackend _backend;

  /// Parses a VTT file content into a
  /// [ThumbnailSprite].
  ///
  /// [vttContent] - The raw VTT file content.
  /// [baseUrl] - Base URL to resolve relative sprite
  ///   image paths.
  ///
  /// Returns null if parsing fails or no valid cues
  /// are found.
  Future<ThumbnailSprite?> parse(String vttContent, String baseUrl) async {
    final result = await _backend.parseVttThumbnails(vttContent, baseUrl);
    if (result == null) return null;

    final imageUrl = result['image_url'] as String?;
    if (imageUrl == null) return null;

    final columns = result['columns'] as int? ?? 1;
    final rows = result['rows'] as int? ?? 1;
    final thumbWidth = result['thumb_width'] as int? ?? 160;
    final thumbHeight = result['thumb_height'] as int? ?? 90;

    final rawCues = result['cues'] as List<dynamic>? ?? [];
    final cues =
        rawCues.map((c) {
          final map = c as Map<String, dynamic>;
          return ThumbnailCue(
            start: Duration(milliseconds: map['start_ms'] as int? ?? 0),
            end: Duration(milliseconds: map['end_ms'] as int? ?? 0),
            x: map['x'] as int? ?? 0,
            y: map['y'] as int? ?? 0,
          );
        }).toList();

    if (cues.isEmpty) return null;

    return ThumbnailSprite(
      imageUrl: imageUrl,
      columns: columns,
      rows: rows,
      thumbWidth: thumbWidth,
      thumbHeight: thumbHeight,
      cues: cues,
    );
  }
}
