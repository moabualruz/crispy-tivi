import 'dart:convert';

import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrispyBackend.mergeCloudBackups', () {
    late MemoryBackend backend;
    late Map<String, dynamic> baseLocal;
    late Map<String, dynamic> baseCloud;

    setUp(() {
      backend = MemoryBackend();
      baseLocal = {
        'version': 3,
        'exportedAt': '2026-02-19T12:00:00.000Z',
        'profiles': <dynamic>[],
        'favorites': <String, dynamic>{},
        'channelOrders': <dynamic>[],
        'sourceAccess': <String, dynamic>{},
        'settings': <String, dynamic>{},
        'watchHistory': <dynamic>[],
        'recordings': <dynamic>[],
        'sources': <dynamic>[],
      };
      baseCloud = {
        'version': 3,
        'exportedAt': '2026-02-19T10:00:00.000Z',
        'profiles': <dynamic>[],
        'favorites': <String, dynamic>{},
        'channelOrders': <dynamic>[],
        'sourceAccess': <String, dynamic>{},
        'settings': <String, dynamic>{},
        'watchHistory': <dynamic>[],
        'recordings': <dynamic>[],
        'sources': <dynamic>[],
      };
    });

    /// Helper: calls backend and parses result.
    Future<Map<String, dynamic>> merge(
      Map<String, dynamic> local,
      Map<String, dynamic> cloud,
      String deviceId,
    ) async {
      final result = await backend.mergeCloudBackups(
        json.encode(local),
        json.encode(cloud),
        deviceId,
      );
      return json.decode(result) as Map<String, dynamic>;
    }

    test('should take max version from both backups', () async {
      baseLocal['version'] = 3;
      baseCloud['version'] = 2;

      final merged = await merge(baseLocal, baseCloud, 'device_1');

      expect(merged['version'], 3);
    });

    group('profiles', () {
      test('should union profiles by ID', () async {
        baseLocal['profiles'] = [
          {'id': 'p1', 'name': 'Alice', 'avatarIndex': 0},
        ];
        baseCloud['profiles'] = [
          {'id': 'p2', 'name': 'Bob', 'avatarIndex': 1},
        ];

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final profiles = merged['profiles'] as List;
        expect(profiles, hasLength(2));
        final ids =
            profiles.map((p) => (p as Map<String, dynamic>)['id']).toSet();
        expect(ids, containsAll(['p1', 'p2']));
      });

      test('should prefer local for duplicate profile IDs', () async {
        baseLocal['profiles'] = [
          {'id': 'p1', 'name': 'Alice Local', 'avatarIndex': 2},
        ];
        baseCloud['profiles'] = [
          {'id': 'p1', 'name': 'Alice Cloud', 'avatarIndex': 0},
        ];

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final profiles = merged['profiles'] as List;
        expect(profiles, hasLength(1));
        expect((profiles.first as Map<String, dynamic>)['name'], 'Alice Local');
      });
    });

    group('favorites', () {
      test('should union favorites per profile', () async {
        baseLocal['favorites'] = {
          'p1': ['ch1', 'ch2'],
        };
        baseCloud['favorites'] = {
          'p1': ['ch2', 'ch3'],
        };

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final favs =
            (merged['favorites'] as Map<String, dynamic>)['p1'] as List;
        expect(favs, hasLength(3));
        expect(favs, containsAll(['ch1', 'ch2', 'ch3']));
      });

      test('should include profiles from both sides', () async {
        baseLocal['favorites'] = {
          'p1': ['ch1'],
        };
        baseCloud['favorites'] = {
          'p2': ['ch5'],
        };

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final favs = merged['favorites'] as Map<String, dynamic>;
        expect(favs, hasLength(2));
        expect(favs.containsKey('p1'), true);
        expect(favs.containsKey('p2'), true);
      });
    });

    group('sourceAccess', () {
      test('should union source access grants per profile', () async {
        baseLocal['sourceAccess'] = {
          'p1': ['src1', 'src2'],
        };
        baseCloud['sourceAccess'] = {
          'p1': ['src2', 'src3'],
        };

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final access =
            (merged['sourceAccess'] as Map<String, dynamic>)['p1'] as List;
        expect(access, hasLength(3));
        expect(access, containsAll(['src1', 'src2', 'src3']));
      });
    });

    group('settings', () {
      test('should prefer local settings when local is newer', () async {
        baseLocal['exportedAt'] = '2026-02-19T12:00:00.000Z';
        baseCloud['exportedAt'] = '2026-02-19T10:00:00.000Z';
        baseLocal['settings'] = {'theme': 'dark', 'locale': 'en'};
        baseCloud['settings'] = {'theme': 'light', 'volume': '80'};

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final settings = merged['settings'] as Map<String, dynamic>;
        // Local overrides cloud when local is newer.
        expect(settings['theme'], 'dark');
        expect(settings['locale'], 'en');
        // Cloud-only settings still present.
        expect(settings['volume'], '80');
      });

      test('should skip sync metadata keys', () async {
        baseLocal['settings'] = {
          'theme': 'dark',
          'crispy_tivi_last_sync_time': '2026-02-19T12:00:00Z',
          'crispy_tivi_local_modified_time': '2026-02-19T12:00:00Z',
        };
        baseCloud['settings'] = {
          'theme': 'light',
          'crispy_tivi_last_sync_time': '2026-02-18T10:00:00Z',
          'crispy_tivi_local_modified_time': '2026-02-18T10:00:00Z',
        };

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final settings = merged['settings'] as Map<String, dynamic>;
        // Sync metadata always kept from local.
        expect(settings['crispy_tivi_last_sync_time'], '2026-02-19T12:00:00Z');
        expect(
          settings['crispy_tivi_local_modified_time'],
          '2026-02-19T12:00:00Z',
        );
      });
    });

    group('watchHistory', () {
      test('should union watch history entries by ID', () async {
        baseLocal['watchHistory'] = [
          {
            'id': 'h1',
            'name': 'Movie A',
            'mediaType': 'vod',
            'streamUrl': 'url1',
            'positionMs': 5000,
            'durationMs': 120000,
            'lastWatched': '2026-02-19T12:00:00.000Z',
          },
        ];
        baseCloud['watchHistory'] = [
          {
            'id': 'h2',
            'name': 'Movie B',
            'mediaType': 'vod',
            'streamUrl': 'url2',
            'positionMs': 3000,
            'durationMs': 90000,
            'lastWatched': '2026-02-19T10:00:00.000Z',
          },
        ];

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final history = merged['watchHistory'] as List;
        expect(history, hasLength(2));
      });

      test('should take later lastWatched for same ID', () async {
        baseLocal['watchHistory'] = [
          {
            'id': 'h1',
            'name': 'Movie A',
            'mediaType': 'vod',
            'streamUrl': 'url1',
            'positionMs': 5000,
            'durationMs': 120000,
            'lastWatched': '2026-02-19T12:00:00.000Z',
          },
        ];
        baseCloud['watchHistory'] = [
          {
            'id': 'h1',
            'name': 'Movie A',
            'mediaType': 'vod',
            'streamUrl': 'url1',
            'positionMs': 3000,
            'durationMs': 120000,
            'lastWatched': '2026-02-19T10:00:00.000Z',
          },
        ];

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final history = merged['watchHistory'] as List;
        expect(history, hasLength(1));
        final entry = history.first as Map<String, dynamic>;
        // Local is newer, so takes local entry.
        expect(entry['lastWatched'], '2026-02-19T12:00:00.000Z');
        // But takes max position (local 5000 > cloud 3000).
        expect(entry['positionMs'], 5000);
      });

      test('should take max positionMs even from older entry', () async {
        baseLocal['watchHistory'] = [
          {
            'id': 'h1',
            'name': 'Movie A',
            'mediaType': 'vod',
            'streamUrl': 'url1',
            'positionMs': 2000,
            'durationMs': 120000,
            'lastWatched': '2026-02-19T12:00:00.000Z',
          },
        ];
        baseCloud['watchHistory'] = [
          {
            'id': 'h1',
            'name': 'Movie A',
            'mediaType': 'vod',
            'streamUrl': 'url1',
            'positionMs': 8000,
            'durationMs': 120000,
            'lastWatched': '2026-02-19T10:00:00.000Z',
          },
        ];

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final history = merged['watchHistory'] as List;
        final entry = history.first as Map<String, dynamic>;
        // Local entry wins (newer), but position taken
        // from cloud.
        expect(entry['lastWatched'], '2026-02-19T12:00:00.000Z');
        expect(entry['positionMs'], 8000);
      });
    });

    group('sources', () {
      test('should union sources by name+URL', () async {
        baseLocal['sources'] = [
          {'name': 'IPTV1', 'url': 'http://a.com/get.php'},
        ];
        baseCloud['sources'] = [
          {'name': 'IPTV2', 'url': 'http://b.com/get.php'},
        ];

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final sources = merged['sources'] as List;
        expect(sources, hasLength(2));
      });

      test('should deduplicate sources with same name+URL', () async {
        baseLocal['sources'] = [
          {'name': 'IPTV1', 'url': 'http://a.com/get.php'},
        ];
        baseCloud['sources'] = [
          {'name': 'IPTV1', 'url': 'http://a.com/get.php'},
        ];

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final sources = merged['sources'] as List;
        expect(sources, hasLength(1));
      });
    });

    group('recordings', () {
      test('should union recordings by ID', () async {
        baseLocal['recordings'] = [
          {'id': 'r1', 'channelName': 'CNN', 'programName': 'News'},
        ];
        baseCloud['recordings'] = [
          {'id': 'r2', 'channelName': 'BBC', 'programName': 'World'},
        ];

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final recordings = merged['recordings'] as List;
        expect(recordings, hasLength(2));
      });
    });

    group('channelOrders', () {
      test('should prefer local channel orders', () async {
        baseLocal['channelOrders'] = [
          {
            'profileId': 'p1',
            'groupName': 'Sports',
            'channelId': 'ch1',
            'sortIndex': 0,
          },
        ];
        baseCloud['channelOrders'] = [
          {
            'profileId': 'p1',
            'groupName': 'Sports',
            'channelId': 'ch1',
            'sortIndex': 5,
          },
        ];

        final merged = await merge(baseLocal, baseCloud, 'device_1');

        final orders = merged['channelOrders'] as List;
        expect(orders, hasLength(1));
        expect((orders.first as Map<String, dynamic>)['sortIndex'], 0);
      });
    });

    test('should handle empty backups gracefully', () async {
      final merged = await merge(
        {'version': 3, 'exportedAt': '2026-02-19T12:00:00.000Z'},
        {'version': 2, 'exportedAt': '2026-02-18T12:00:00.000Z'},
        'device_1',
      );

      expect(merged['version'], 3);
      expect(merged['profiles'], isEmpty);
      expect(merged['favorites'], isEmpty);
      expect(merged['watchHistory'], isEmpty);
      expect(merged['sources'], isEmpty);
    });
  });
}
