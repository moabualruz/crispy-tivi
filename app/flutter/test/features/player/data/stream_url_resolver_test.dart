import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/player/data/stream_url_resolver.dart';

void main() {
  // ── Fixtures ────────────────────────────────────────────────────────────

  const embySource = PlaylistSource(
    id: 'src1',
    name: 'My Emby',
    url: 'http://emby.local:8096',
    type: PlaylistSourceType.emby,
    accessToken: 'emby-token-abc',
    deviceId: 'device-emby-01',
  );

  const jellyfinSource = PlaylistSource(
    id: 'src1',
    name: 'My Jellyfin',
    url: 'http://jf.local:8096',
    type: PlaylistSourceType.jellyfin,
    accessToken: 'jf-token-xyz',
    deviceId: 'device-jf-01',
  );

  const plexSource = PlaylistSource(
    id: 'src1',
    name: 'My Plex',
    url: 'http://plex.local:32400',
    type: PlaylistSourceType.plex,
    accessToken: 'plex-token-def',
    deviceId: 'plex-client-01',
  );

  // ── HTTP pass-through ────────────────────────────────────────────────────

  group('HTTP / HTTPS URLs — pass-through', () {
    test('returns null for http:// URL', () async {
      final resolver = StreamUrlResolver([embySource]);
      final result = await resolver.resolve('http://cdn.example.com/movie.mp4');
      expect(result, isNull);
    });

    test('returns null for https:// URL', () async {
      final resolver = StreamUrlResolver([embySource]);
      final result = await resolver.resolve(
        'https://cdn.example.com/movie.mp4',
      );
      expect(result, isNull);
    });
  });

  // ── Emby resolution ─────────────────────────────────────────────────────

  group('emby:// — resolution', () {
    test('resolves emby://src1/abc123 to correct stream URL', () async {
      final resolver = StreamUrlResolver([embySource]);
      final result = await resolver.resolve('emby://src1/abc123');

      expect(result, isNotNull);
      expect(
        result!.url,
        'http://emby.local:8096/Videos/abc123/stream'
        '?static=true&api_key=emby-token-abc',
      );
    });

    test('includes X-Emby-Authorization header', () async {
      final resolver = StreamUrlResolver([embySource]);
      final result = await resolver.resolve('emby://src1/abc123');

      expect(result!.headers, isNotNull);
      expect(result.headers!.containsKey('X-Emby-Authorization'), isTrue);
      expect(
        result.headers!['X-Emby-Authorization'],
        contains('DeviceId="device-emby-01"'),
      );
    });
  });

  // ── Jellyfin resolution ──────────────────────────────────────────────────

  group('jellyfin:// — resolution', () {
    test('resolves jellyfin://src1/abc123 to same pattern as emby', () async {
      final resolver = StreamUrlResolver([jellyfinSource]);
      final result = await resolver.resolve('jellyfin://src1/abc123');

      expect(result, isNotNull);
      expect(
        result!.url,
        'http://jf.local:8096/Videos/abc123/stream'
        '?static=true&api_key=jf-token-xyz',
      );
    });

    test('includes X-Emby-Authorization header for Jellyfin', () async {
      final resolver = StreamUrlResolver([jellyfinSource]);
      final result = await resolver.resolve('jellyfin://src1/abc123');

      expect(result!.headers, isNotNull);
      expect(result.headers!.containsKey('X-Emby-Authorization'), isTrue);
      expect(
        result.headers!['X-Emby-Authorization'],
        contains('DeviceId="device-jf-01"'),
      );
    });
  });

  // ── Plex resolution ──────────────────────────────────────────────────────

  group('plex:// — resolution', () {
    test('resolves plex://src1/12345 to Plex metadata URL', () async {
      final resolver = StreamUrlResolver([plexSource]);
      final result = await resolver.resolve('plex://src1/12345');

      expect(result, isNotNull);
      expect(
        result!.url,
        'http://plex.local:32400/library/metadata/12345'
        '?X-Plex-Token=plex-token-def',
      );
    });

    test('includes X-Plex-Token header', () async {
      final resolver = StreamUrlResolver([plexSource]);
      final result = await resolver.resolve('plex://src1/12345');

      expect(result!.headers, isNotNull);
      expect(result.headers!['X-Plex-Token'], 'plex-token-def');
    });

    test('includes X-Plex-Client-Identifier header', () async {
      final resolver = StreamUrlResolver([plexSource]);
      final result = await resolver.resolve('plex://src1/12345');

      expect(result!.headers!['X-Plex-Client-Identifier'], 'plex-client-01');
    });
  });

  // ── Unknown source ───────────────────────────────────────────────────────

  group('unknown source ID', () {
    test('throws StateError when source ID is not found', () async {
      final resolver = StreamUrlResolver([embySource]);
      expect(
        () => resolver.resolve('emby://no-such-source/abc'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('no-such-source'),
          ),
        ),
      );
    });
  });

  // ── Invalid / unrecognised URL ────────────────────────────────────────────

  group('invalid / unrecognised URL', () {
    test('returns null for an unparseable URL', () async {
      final resolver = StreamUrlResolver([embySource]);
      // Uri.tryParse returns null for truly malformed strings; however
      // most strings parse to *something* in Dart. Use a known-bad
      // scheme to exercise the unknown-scheme path.
      final result = await resolver.resolve('not-a-scheme:///path');
      expect(result, isNull);
    });

    test('returns null for an unknown synthetic scheme', () async {
      final resolver = StreamUrlResolver([]);
      final result = await resolver.resolve('ftp://host/path');
      expect(result, isNull);
    });
  });

  // ── URI parsing verification ─────────────────────────────────────────────

  // Dart's Uri.parse() lowercases the authority (host) component.
  // These tests document the actual behavior.
  group('URI scheme parsing', () {
    test('Uri.parse of plex://sourceId/itemId lowercases host to sourceid', () {
      final uri = Uri.parse('plex://sourceId/itemId');
      expect(uri.scheme, 'plex');
      expect(uri.host, 'sourceid'); // Dart lowercases the authority.
      expect(uri.pathSegments, ['itemId']);
    });

    test('Uri.parse of emby://sourceId/itemId lowercases host to sourceid', () {
      final uri = Uri.parse('emby://sourceId/itemId');
      expect(uri.scheme, 'emby');
      expect(uri.host, 'sourceid');
      expect(uri.pathSegments, ['itemId']);
    });

    test(
      'Uri.parse of jellyfin://sourceId/itemId lowercases host to sourceid',
      () {
        final uri = Uri.parse('jellyfin://sourceId/itemId');
        expect(uri.scheme, 'jellyfin');
        expect(uri.host, 'sourceid');
        expect(uri.pathSegments, ['itemId']);
      },
    );

    test('resolver matches source despite URI host lowercasing', () async {
      const mixedCaseSource = PlaylistSource(
        id: 'SourceID',
        name: 'Mixed',
        url: 'http://server.local',
        type: PlaylistSourceType.emby,
        accessToken: 'tok',
      );
      final resolver = StreamUrlResolver([mixedCaseSource]);
      // Uri.parse lowercases 'SourceID' → 'sourceid', but the resolver
      // performs case-insensitive lookup so it still resolves.
      final result = await resolver.resolve('emby://SourceID/item1');
      expect(result, isNotNull);
      expect(result!.url, contains('/Videos/item1/stream'));
    });
  });
}
