import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/iptv/data/parsers/epg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CrispyBackend backend;

  setUp(() {
    backend = MemoryBackend();
  });

  group('EpgParser', () {
    group('parseContent', () {
      test('returns empty list for empty content', () async {
        final entries = await EpgParser.parseContent('', backend);
        expect(entries, isEmpty);
      });

      test('returns empty list for whitespace-only'
          ' content', () async {
        final entries = await EpgParser.parseContent('   \n  \t  ', backend);
        expect(entries, isEmpty);
      });

      test('delegates to backend for non-empty'
          ' content', () async {
        // MemoryBackend.parseEpg returns [],
        // so we get an empty list back.
        const xml =
            '<?xml version="1.0"?>'
            '<tv><programme '
            'start="20260216060000 +0000" '
            'stop="20260216070000 +0000" '
            'channel="test">'
            '<title>Test</title>'
            '</programme></tv>';

        final entries = await EpgParser.parseContent(xml, backend);
        expect(entries, isEmpty);
      });

      test('returns List<EpgEntry> type', () async {
        final entries = await EpgParser.parseContent('', backend);
        expect(entries, isA<List>());
      });
    });

    group('parseInIsolate', () {
      test('delegates to parseContent', () async {
        final entries = await EpgParser.parseInIsolate('', backend);
        expect(entries, isEmpty);
      });

      test('returns same result as parseContent', () async {
        const xml =
            '<?xml version="1.0"?>'
            '<tv><programme '
            'start="20260216060000 +0000" '
            'stop="20260216070000 +0000" '
            'channel="test">'
            '<title>Test</title>'
            '</programme></tv>';

        final direct = await EpgParser.parseContent(xml, backend);
        final isolate = await EpgParser.parseInIsolate(xml, backend);

        expect(isolate.length, direct.length);
      });
    });

    group('extractChannelNames', () {
      test('returns empty map for empty content', () async {
        // Empty content triggers the
        // trim().isEmpty guard in parseContent,
        // but extractChannelNames delegates
        // directly to backend.
        final names = await EpgParser.extractChannelNames('', backend);
        expect(names, isEmpty);
      });

      test('extractChannelNamesInIsolate delegates'
          ' to extractChannelNames', () async {
        final direct = await EpgParser.extractChannelNames('<tv/>', backend);
        final isolate = await EpgParser.extractChannelNamesInIsolate(
          '<tv/>',
          backend,
        );

        expect(isolate, equals(direct));
      });
    });
  });
}
