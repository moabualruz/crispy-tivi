import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/features/player/data/vtt_parser.dart';

// ── Mocks ──────────────────────────────────────────

class MockCrispyBackend extends Mock implements CrispyBackend {}

void main() {
  late MockCrispyBackend mockBackend;
  late VttParser parser;

  setUp(() {
    mockBackend = MockCrispyBackend();
    parser = VttParser(mockBackend);
  });

  // ── parse() — valid VTT ──────────────────────────

  group('parse() — valid VTT', () {
    test('returns ThumbnailSprite from valid backend result', () async {
      when(() => mockBackend.parseVttThumbnails(any(), any())).thenAnswer(
        (_) async => <String, dynamic>{
          'image_url': 'http://example.com/sprites/tile.jpg',
          'columns': 10,
          'rows': 5,
          'thumb_width': 160,
          'thumb_height': 90,
          'cues': <Map<String, dynamic>>[
            {'start_ms': 0, 'end_ms': 5000, 'x': 0, 'y': 0},
            {'start_ms': 5000, 'end_ms': 10000, 'x': 160, 'y': 0},
          ],
        },
      );

      final result = await parser.parse(
        'WEBVTT\n\n00:00:00.000 --> 00:00:05.000\n'
            'tile.jpg#xywh=0,0,160,90',
        'http://example.com/sprites/',
      );

      expect(result, isNotNull);
      expect(result!.imageUrl, 'http://example.com/sprites/tile.jpg');
      expect(result.columns, 10);
      expect(result.rows, 5);
      expect(result.thumbWidth, 160);
      expect(result.thumbHeight, 90);
      expect(result.cues, hasLength(2));
    });

    test('cue start and end durations are correct', () async {
      when(() => mockBackend.parseVttThumbnails(any(), any())).thenAnswer(
        (_) async => <String, dynamic>{
          'image_url': 'http://x.com/tile.jpg',
          'columns': 1,
          'rows': 1,
          'thumb_width': 160,
          'thumb_height': 90,
          'cues': <Map<String, dynamic>>[
            {'start_ms': 1500, 'end_ms': 3000, 'x': 320, 'y': 180},
          ],
        },
      );

      final result = await parser.parse('vtt', 'base');

      expect(result, isNotNull);
      final cue = result!.cues.first;
      expect(cue.start, const Duration(milliseconds: 1500));
      expect(cue.end, const Duration(milliseconds: 3000));
      expect(cue.x, 320);
      expect(cue.y, 180);
    });

    test('uses default values for missing optional fields', () async {
      when(() => mockBackend.parseVttThumbnails(any(), any())).thenAnswer(
        (_) async => <String, dynamic>{
          'image_url': 'http://x.com/tile.jpg',
          // columns, rows, thumb_width, thumb_height
          // all missing — should default.
          'cues': <Map<String, dynamic>>[
            {
              // start_ms, end_ms, x, y all missing
              // — should default to 0.
            },
          ],
        },
      );

      final result = await parser.parse('vtt', 'base');

      expect(result, isNotNull);
      expect(result!.columns, 1);
      expect(result.rows, 1);
      expect(result.thumbWidth, 160);
      expect(result.thumbHeight, 90);

      final cue = result.cues.first;
      expect(cue.start, Duration.zero);
      expect(cue.end, Duration.zero);
      expect(cue.x, 0);
      expect(cue.y, 0);
    });

    test('passes vttContent and baseUrl to backend', () async {
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => null);

      await parser.parse(
        'WEBVTT content here',
        'http://cdn.example.com/thumbs/',
      );

      verify(
        () => mockBackend.parseVttThumbnails(
          'WEBVTT content here',
          'http://cdn.example.com/thumbs/',
        ),
      ).called(1);
    });
  });

  // ── parse() — null / invalid results ─────────────

  group('parse() — null and invalid results', () {
    test('returns null when backend returns null', () async {
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => null);

      final result = await parser.parse('', '');

      expect(result, isNull);
    });

    test('returns null when image_url is missing', () async {
      when(() => mockBackend.parseVttThumbnails(any(), any())).thenAnswer(
        (_) async => <String, dynamic>{
          'columns': 10,
          'rows': 5,
          'cues': <Map<String, dynamic>>[
            {'start_ms': 0, 'end_ms': 5000, 'x': 0, 'y': 0},
          ],
        },
      );

      final result = await parser.parse('vtt', 'base');

      expect(result, isNull);
    });

    test('returns null when cues list is empty', () async {
      when(() => mockBackend.parseVttThumbnails(any(), any())).thenAnswer(
        (_) async => <String, dynamic>{
          'image_url': 'http://x.com/tile.jpg',
          'columns': 10,
          'rows': 5,
          'thumb_width': 160,
          'thumb_height': 90,
          'cues': <Map<String, dynamic>>[],
        },
      );

      final result = await parser.parse('vtt', 'base');

      expect(result, isNull);
    });

    test('returns null when cues key is missing', () async {
      when(() => mockBackend.parseVttThumbnails(any(), any())).thenAnswer(
        (_) async => <String, dynamic>{
          'image_url': 'http://x.com/tile.jpg',
          'columns': 10,
          'rows': 5,
        },
      );

      final result = await parser.parse('vtt', 'base');

      expect(result, isNull);
    });
  });

  // ── parse() — empty / malformed input ────────────

  group('parse() — empty and malformed input', () {
    test('returns null for empty VTT content', () async {
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => null);

      final result = await parser.parse('', '');

      expect(result, isNull);
    });

    test('returns null for non-VTT content', () async {
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => null);

      final result = await parser.parse(
        '<!DOCTYPE html><html></html>',
        'http://example.com/',
      );

      expect(result, isNull);
    });

    test('returns null for empty base URL', () async {
      when(
        () => mockBackend.parseVttThumbnails(any(), any()),
      ).thenAnswer((_) async => null);

      final result = await parser.parse(
        'WEBVTT\n\n00:00:00.000 --> 00:00:05.000',
        '',
      );

      expect(result, isNull);
    });
  });

  // ── parse() — multiple cues ──────────────────────

  group('parse() — multiple cues', () {
    test('preserves cue order from backend', () async {
      when(() => mockBackend.parseVttThumbnails(any(), any())).thenAnswer(
        (_) async => <String, dynamic>{
          'image_url': 'http://x.com/tile.jpg',
          'columns': 4,
          'rows': 3,
          'thumb_width': 160,
          'thumb_height': 90,
          'cues': <Map<String, dynamic>>[
            {'start_ms': 0, 'end_ms': 2000, 'x': 0, 'y': 0},
            {'start_ms': 2000, 'end_ms': 4000, 'x': 160, 'y': 0},
            {'start_ms': 4000, 'end_ms': 6000, 'x': 320, 'y': 0},
            {'start_ms': 6000, 'end_ms': 8000, 'x': 480, 'y': 0},
            {'start_ms': 8000, 'end_ms': 10000, 'x': 0, 'y': 90},
          ],
        },
      );

      final result = await parser.parse('vtt', 'base');

      expect(result, isNotNull);
      expect(result!.cues, hasLength(5));
      expect(result.cues[0].x, 0);
      expect(result.cues[1].x, 160);
      expect(result.cues[2].x, 320);
      expect(result.cues[3].x, 480);
      expect(result.cues[4].x, 0);
      expect(result.cues[4].y, 90);
    });

    test('returns correct thumbnailCount', () async {
      when(() => mockBackend.parseVttThumbnails(any(), any())).thenAnswer(
        (_) async => <String, dynamic>{
          'image_url': 'http://x.com/tile.jpg',
          'columns': 4,
          'rows': 3,
          'thumb_width': 160,
          'thumb_height': 90,
          'cues': <Map<String, dynamic>>[
            {'start_ms': 0, 'end_ms': 2000, 'x': 0, 'y': 0},
          ],
        },
      );

      final result = await parser.parse('vtt', 'base');

      expect(result, isNotNull);
      expect(result!.thumbnailCount, 12);
    });
  });
}
