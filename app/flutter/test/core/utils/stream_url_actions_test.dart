import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/utils/stream_url_actions.dart';

void main() {
  group('normalizeStreamUrl', () {
    test('returns original URL on native platforms', () {
      const url = 'http://example.com/stream.ts';
      expect(normalizeStreamUrl(url, isWeb: false), url);
    });

    test('converts .ts to .m3u8 on web', () {
      const url = 'http://example.com/stream.ts';
      expect(
        normalizeStreamUrl(url, isWeb: true),
        'http://example.com/stream.m3u8',
      );
    });

    test('appends .m3u8 to extensionless live Xtream URLs on web', () {
      const url = 'http://example.com/live/user/pass/123';
      expect(normalizeStreamUrl(url, isWeb: true), '$url.m3u8');
    });

    test('does not append .m3u8 if already present on web', () {
      const url = 'http://example.com/stream.m3u8';
      expect(normalizeStreamUrl(url, isWeb: true), url);
    });

    test('does not append .m3u8 to VOD URLs on web', () {
      const url = 'http://example.com/movie.mp4';
      expect(normalizeStreamUrl(url, isWeb: true), url);
    });

    test('converts .ts with query params on web', () {
      const url = 'http://example.com/stream.ts?token=abc';
      expect(
        normalizeStreamUrl(url, isWeb: true),
        'http://example.com/stream.m3u8?token=abc',
      );
    });

    test(
      'appends .m3u8 to extensionless live URL with query params on web',
      () {
        const url = 'http://example.com/live/user/pass/123?token=abc';
        expect(
          normalizeStreamUrl(url, isWeb: true),
          'http://example.com/live/user/pass/123.m3u8?token=abc',
        );
      },
    );

    test('handles trailing slash in live URL on web', () {
      const url = 'http://example.com/live/user/pass/123/';
      // Trailing slash means last segment is empty — should NOT append .m3u8
      expect(normalizeStreamUrl(url, isWeb: true), url);
    });

    test('does not modify non-live extensionless URLs on web', () {
      const url = 'http://example.com/vod/user/pass/123';
      expect(normalizeStreamUrl(url, isWeb: true), url);
    });
  });
}
