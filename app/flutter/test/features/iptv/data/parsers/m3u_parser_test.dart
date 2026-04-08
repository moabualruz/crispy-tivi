import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/iptv/data/parsers/m3u_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CrispyBackend backend;

  setUp(() {
    backend = MemoryBackend();
  });

  group('M3uParser', () {
    group('parseContent', () {
      test('returns empty result for empty content', () async {
        final result = await M3uParser.parseContent('', backend);
        expect(result.channels, isEmpty);
        expect(result.epgUrl, isNull);
      });

      test('returns empty result for whitespace-only'
          ' content', () async {
        final result = await M3uParser.parseContent('   \n  \t  ', backend);
        expect(result.channels, isEmpty);
        expect(result.epgUrl, isNull);
      });

      test('delegates to backend for non-empty'
          ' content', () async {
        // MemoryBackend.parseM3u returns
        // {channels: []}, so we get an empty
        // but valid M3uParseResult.
        final result = await M3uParser.parseContent(
          '#EXTM3U\n#EXTINF:-1,Ch\nhttp://x',
          backend,
        );
        expect(result.channels, isEmpty);
        expect(result.epgUrl, isNull);
      });

      test('M3uParseResult has correct structure', () async {
        final result = await M3uParser.parseContent('', backend);
        expect(result, isA<M3uParseResult>());
        expect(result.channels, isA<List>());
      });
    });

    group('parseInIsolate', () {
      test('delegates to parseContent', () async {
        final result = await M3uParser.parseInIsolate('', backend);
        expect(result.channels, isEmpty);
        expect(result.epgUrl, isNull);
      });

      test('returns same result as parseContent', () async {
        const content =
            '#EXTM3U\n#EXTINF:-1,Test\n'
            'http://example.com/stream';

        final direct = await M3uParser.parseContent(content, backend);
        final isolate = await M3uParser.parseInIsolate(content, backend);

        expect(isolate.channels.length, direct.channels.length);
        expect(isolate.epgUrl, direct.epgUrl);
      });
    });
  });
}
