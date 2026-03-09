import 'dart:convert';
import 'dart:typed_data';

import '../domain/entities/thumbnail_sprite.dart';

/// Parsed BIF index entry (from Rust FFI JSON output).
class _BifEntry {
  const _BifEntry({
    required this.timestampMs,
    required this.offset,
    required this.length,
  });

  factory _BifEntry.fromJson(Map<String, dynamic> json) {
    return _BifEntry(
      timestampMs: (json['timestamp_ms'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
      length: (json['length'] as num).toInt(),
    );
  }

  final int timestampMs;
  final int offset;
  final int length;
}

/// BIF trickplay thumbnail data implementing [ThumbnailSource].
///
/// Holds the raw BIF file bytes and parsed index in memory.
/// Thumbnail lookup is O(log n) binary search on the index,
/// followed by an O(1) byte slice — no FFI call per hover.
class BifThumbnailData implements ThumbnailSource {
  BifThumbnailData._(this._data, this._entries);

  /// Creates [BifThumbnailData] from raw BIF file bytes and
  /// the JSON index string returned by the Rust FFI
  /// `parseBifIndex` function.
  factory BifThumbnailData.fromIndexJson(Uint8List data, String indexJson) {
    final decoded = jsonDecode(indexJson) as List<dynamic>;
    final entries = decoded
        .cast<Map<String, dynamic>>()
        .map(_BifEntry.fromJson)
        .toList(growable: false);
    return BifThumbnailData._(data, entries);
  }

  final Uint8List _data;
  final List<_BifEntry> _entries;

  /// Number of thumbnail frames in this BIF file.
  int get frameCount => _entries.length;

  @override
  ThumbnailRegion? getRegionAt(Duration position) {
    if (_entries.isEmpty) return null;

    final targetMs = position.inMilliseconds;
    if (targetMs < 0) return null;

    // Binary search for nearest-preceding entry.
    var lo = 0;
    var hi = _entries.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_entries[mid].timestampMs <= targetMs) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }

    final entry = _entries[lo];
    if (entry.timestampMs > targetMs) return null;

    final end = entry.offset + entry.length;
    if (end > _data.length) return null;

    return ThumbnailRegion(
      imageBytes: Uint8List.sublistView(_data, entry.offset, end),
      x: 0,
      y: 0,
      width: 160,
      height: 90,
    );
  }
}
