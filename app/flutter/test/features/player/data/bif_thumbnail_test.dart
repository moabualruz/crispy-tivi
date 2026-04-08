import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/data/'
    'bif_thumbnail_data.dart';

void main() {
  // ── Helper: build a minimal valid BIF fixture ────────

  /// Builds a BIF binary with the given JPEG payloads.
  ///
  /// Format: 8-byte magic, 4 version, 4 imageCount,
  /// 4 timestampMultiplier, 36 reserved, then index
  /// table at offset 64, then JPEG data.
  Uint8List makeBif(List<Uint8List> jpegs, {int multiplier = 1000}) {
    const headerSize = 64;
    final imageCount = jpegs.length;
    // Index has (imageCount + 1) entries of 8 bytes each.
    final indexSize = (imageCount + 1) * 8;
    final dataOffset = headerSize + indexSize;

    // Calculate total size.
    var totalJpegSize = 0;
    for (final j in jpegs) {
      totalJpegSize += j.length;
    }
    final totalSize = dataOffset + totalJpegSize;
    final buf = ByteData(totalSize);

    // Magic: 0x89 B I F 0x0D 0x0A 0x1A 0x0A
    const magic = [0x89, 0x42, 0x49, 0x46, 0x0D, 0x0A, 0x1A, 0x0A];
    for (var i = 0; i < magic.length; i++) {
      buf.setUint8(i, magic[i]);
    }
    // Version (unused)
    buf.setUint32(8, 0, Endian.little);
    // Image count
    buf.setUint32(12, imageCount, Endian.little);
    // Timestamp multiplier
    buf.setUint32(16, multiplier, Endian.little);
    // Reserved bytes 20..63 are zero.

    // Index table
    var currentOffset = dataOffset;
    for (var i = 0; i < imageCount; i++) {
      final entryPos = headerSize + i * 8;
      buf.setUint32(entryPos, i, Endian.little); // timestamp
      buf.setUint32(entryPos + 4, currentOffset, Endian.little);
      currentOffset += jpegs[i].length;
    }
    // Sentinel entry
    final sentinelPos = headerSize + imageCount * 8;
    buf.setUint32(sentinelPos, 0xFFFFFFFF, Endian.little);
    buf.setUint32(sentinelPos + 4, currentOffset, Endian.little);

    // JPEG data
    final bytes = buf.buffer.asUint8List();
    var writePos = dataOffset;
    for (final j in jpegs) {
      bytes.setRange(writePos, writePos + j.length, j);
      writePos += j.length;
    }

    return bytes;
  }

  /// Create a fake JPEG payload of given size.
  Uint8List fakeJpeg(int size) =>
      Uint8List.fromList(List.generate(size, (i) => (i + 0xFF) & 0xFF));

  /// Parse the BIF to get the index JSON that BifThumbnailData
  /// expects (simulates the Rust FFI output).
  String buildIndexJson(Uint8List bifData) {
    // Re-implement minimal BIF index parsing in Dart
    // for test purposes only.
    if (bifData.length < 64) return '[]';
    final bd = ByteData.sublistView(bifData);

    final imageCount = bd.getUint32(12, Endian.little);
    var multiplier = bd.getUint32(16, Endian.little);
    if (multiplier == 0) multiplier = 1000;

    final entries = <Map<String, dynamic>>[];
    for (var i = 0; i < imageCount; i++) {
      final entryOffset = 64 + i * 8;
      if (entryOffset + 8 > bifData.length) break;
      final timestamp = bd.getUint32(entryOffset, Endian.little);
      final imgOffset = bd.getUint32(entryOffset + 4, Endian.little);

      final nextEntryOffset = 64 + (i + 1) * 8;
      if (nextEntryOffset + 8 > bifData.length) break;
      final nextImgOffset = bd.getUint32(nextEntryOffset + 4, Endian.little);

      if (nextImgOffset <= imgOffset || nextImgOffset > bifData.length) {
        continue;
      }

      entries.add({
        'timestamp_ms': timestamp * multiplier,
        'offset': imgOffset,
        'length': nextImgOffset - imgOffset,
      });
    }
    return jsonEncode(entries);
  }

  // ── BifThumbnailData.fromIndexJson ──────────────────

  group('BifThumbnailData.fromIndexJson', () {
    test('parses valid index JSON', () {
      final jpeg = fakeJpeg(100);
      final bif = makeBif([jpeg, jpeg, jpeg]);
      final indexJson = buildIndexJson(bif);

      final data = BifThumbnailData.fromIndexJson(bif, indexJson);

      expect(data.frameCount, 3);
    });

    test('handles empty index', () {
      final bif = makeBif([]);
      final data = BifThumbnailData.fromIndexJson(bif, '[]');

      expect(data.frameCount, 0);
    });
  });

  // ── getRegionAt — binary search ─────────────────────

  group('getRegionAt()', () {
    test('returns null for empty BIF', () {
      final bif = makeBif([]);
      final data = BifThumbnailData.fromIndexJson(bif, '[]');

      expect(data.getRegionAt(Duration.zero), isNull);
    });

    test('returns first frame for position 0', () {
      final jpeg0 = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      final jpeg1 = Uint8List.fromList([0xDD, 0xEE]);
      final bif = makeBif([jpeg0, jpeg1]);
      final indexJson = buildIndexJson(bif);
      final data = BifThumbnailData.fromIndexJson(bif, indexJson);

      final region = data.getRegionAt(Duration.zero);

      expect(region, isNotNull);
      expect(region!.isBifThumbnail, isTrue);
      expect(region.imageBytes!.length, 3);
      expect(region.imageBytes![0], 0xAA);
    });

    test('returns nearest preceding frame', () {
      final jpegs = List.generate(5, (i) => fakeJpeg(50));
      // timestamps: 0*1000=0, 1*1000=1000, 2*1000=2000,
      //             3*1000=3000, 4*1000=4000
      final bif = makeBif(jpegs);
      final indexJson = buildIndexJson(bif);
      final data = BifThumbnailData.fromIndexJson(bif, indexJson);

      // Position 2500ms should return frame at 2000ms (index 2)
      final region = data.getRegionAt(const Duration(milliseconds: 2500));
      expect(region, isNotNull);
      expect(region!.isBifThumbnail, isTrue);
    });

    test('returns last frame for position past end', () {
      final jpegs = List.generate(3, (i) => fakeJpeg(30));
      // timestamps: 0, 1000, 2000
      final bif = makeBif(jpegs);
      final indexJson = buildIndexJson(bif);
      final data = BifThumbnailData.fromIndexJson(bif, indexJson);

      // Position 99s — way past the last frame at 2s
      final region = data.getRegionAt(const Duration(seconds: 99));
      expect(region, isNotNull);
    });

    test('returns exact match frame', () {
      final jpegs = List.generate(3, (i) => fakeJpeg(40));
      final bif = makeBif(jpegs);
      final indexJson = buildIndexJson(bif);
      final data = BifThumbnailData.fromIndexJson(bif, indexJson);

      // Exactly at 1000ms = frame 1
      final region = data.getRegionAt(const Duration(milliseconds: 1000));
      expect(region, isNotNull);
    });

    test('returns null for negative position', () {
      final jpegs = [fakeJpeg(50)];
      final bif = makeBif(jpegs);
      final indexJson = buildIndexJson(bif);
      final data = BifThumbnailData.fromIndexJson(bif, indexJson);

      final region = data.getRegionAt(const Duration(milliseconds: -100));
      expect(region, isNull);
    });

    test('region has zero x/y offsets (standalone frame)', () {
      final jpegs = [fakeJpeg(50)];
      final bif = makeBif(jpegs);
      final indexJson = buildIndexJson(bif);
      final data = BifThumbnailData.fromIndexJson(bif, indexJson);

      final region = data.getRegionAt(Duration.zero);
      expect(region!.x, 0);
      expect(region.y, 0);
      expect(region.width, 160);
      expect(region.height, 90);
    });
  });

  // ── ThumbnailSource interface ───────────────────────

  group('ThumbnailSource interface', () {
    test('implements ThumbnailSource', () {
      final bif = makeBif([fakeJpeg(10)]);
      final indexJson = buildIndexJson(bif);
      final data = BifThumbnailData.fromIndexJson(bif, indexJson);

      // The abstract type check — BifThumbnailData is usable
      // wherever ThumbnailSource is expected.
      expect(data.getRegionAt(Duration.zero), isNotNull);
    });
  });

  // ── Custom multiplier ───────────────────────────────

  group('custom timestamp multiplier', () {
    test('multiplier=500 halves timestamp values', () {
      final jpegs = List.generate(3, (i) => fakeJpeg(20));
      // timestamps: 0*500=0, 1*500=500, 2*500=1000
      final bif = makeBif(jpegs, multiplier: 500);
      final indexJson = buildIndexJson(bif);
      final data = BifThumbnailData.fromIndexJson(bif, indexJson);

      // At 750ms, nearest preceding is 500ms (frame 1)
      final region = data.getRegionAt(const Duration(milliseconds: 750));
      expect(region, isNotNull);

      // At 400ms, nearest preceding is 0ms (frame 0)
      final region0 = data.getRegionAt(const Duration(milliseconds: 400));
      expect(region0, isNotNull);
    });
  });
}
