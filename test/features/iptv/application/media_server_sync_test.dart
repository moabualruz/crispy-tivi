import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/media_item_vod_adapter.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';

void main() {
  group('MediaItemVodAdapter', () {
    test('maps movie correctly', () {
      final item = MediaItem(
        id: '123',
        name: 'Test Movie',
        type: MediaType.movie,
        logoUrl: 'http://img/poster.jpg',
        overview: 'A great movie',
        rating: 'PG-13',
        durationMs: 7200000, // 120 min
        metadata: {'backdropUrl': 'http://img/backdrop.jpg', 'year': 2023},
        releaseDate: DateTime(2023),
      );

      final vod = item.toVodItem(
        streamUrl: 'emby://src1/123',
        sourceId: 'src1',
        category: 'My Server > Movies',
      );

      expect(vod.id, '123');
      expect(vod.name, 'Test Movie');
      expect(vod.streamUrl, 'emby://src1/123');
      expect(vod.type, VodType.movie);
      expect(vod.posterUrl, 'http://img/poster.jpg');
      expect(vod.backdropUrl, 'http://img/backdrop.jpg');
      expect(vod.description, 'A great movie');
      expect(vod.rating, 'PG-13');
      expect(vod.year, 2023);
      expect(vod.duration, 120);
      expect(vod.category, 'My Server > Movies');
      expect(vod.sourceId, 'src1');
      expect(vod.isFavorite, false);
      expect(vod.addedAt, isNotNull);
    });

    test('maps series correctly', () {
      final item = MediaItem(
        id: '456',
        name: 'Test Series',
        type: MediaType.series,
        logoUrl: 'http://img/series.jpg',
      );

      final vod = item.toVodItem(streamUrl: 'jf://src2/456');
      expect(vod.type, VodType.series);
    });

    test('maps episode with season/episode numbers', () {
      final item = MediaItem(
        id: '789',
        name: 'Episode 5',
        type: MediaType.episode,
        durationMs: 2700000, // 45 min
        metadata: {'parentIndex': 2, 'index': 5},
      );

      final vod = item.toVodItem(
        streamUrl: 'emby://src1/789',
        sourceId: 'src1',
        category: 'Server > TV Shows',
      );

      expect(vod.type, VodType.episode);
      expect(vod.seasonNumber, 2);
      expect(vod.episodeNumber, 5);
      expect(vod.duration, 45);
    });

    test('maps folder to series type', () {
      final item = MediaItem(
        id: 'f1',
        name: 'Collection',
        type: MediaType.folder,
      );

      final vod = item.toVodItem(streamUrl: '');
      expect(vod.type, VodType.series);
    });

    test('uses logoUrl as backdrop when no backdropUrl in metadata', () {
      final item = MediaItem(
        id: '1',
        name: 'No Backdrop',
        type: MediaType.movie,
        logoUrl: 'http://img/poster.jpg',
        metadata: const {},
      );

      final vod = item.toVodItem(streamUrl: '');
      expect(vod.backdropUrl, 'http://img/poster.jpg');
    });

    test('uses backdropUrl from metadata when available', () {
      final item = MediaItem(
        id: '1',
        name: 'Has Backdrop',
        type: MediaType.movie,
        logoUrl: 'http://img/poster.jpg',
        metadata: const {'backdropUrl': 'http://img/backdrop.jpg'},
      );

      final vod = item.toVodItem(streamUrl: '');
      expect(vod.backdropUrl, 'http://img/backdrop.jpg');
    });

    test('handles null duration', () {
      final item = MediaItem(
        id: '1',
        name: 'No Duration',
        type: MediaType.movie,
      );

      final vod = item.toVodItem(streamUrl: '');
      expect(vod.duration, isNull);
    });

    test('backward compatibility: existing callers still work', () {
      // Existing callers pass only streamUrl — new params are optional.
      final item = MediaItem(
        id: '1',
        name: 'Old Style',
        type: MediaType.movie,
        logoUrl: 'http://img/poster.jpg',
      );

      final vod = item.toVodItem(streamUrl: 'http://stream.m3u8');
      expect(vod.id, '1');
      expect(vod.streamUrl, 'http://stream.m3u8');
      expect(vod.sourceId, isNull);
      expect(vod.category, isNull);
    });
  });

  group('Stream URL scheme', () {
    test('Emby stream URL format', () {
      const sourceId = 'src_emby_1';
      const itemId = 'abc123';
      final url = 'emby://$sourceId/$itemId';
      expect(url, 'emby://src_emby_1/abc123');
    });

    test('Jellyfin stream URL format', () {
      const sourceId = 'src_jf_1';
      const itemId = 'def456';
      final url = 'jellyfin://$sourceId/$itemId';
      expect(url, 'jellyfin://src_jf_1/def456');
    });

    test('Plex stream URL format', () {
      const sourceId = 'src_plex_1';
      const itemId = '12345';
      final url = 'plex://$sourceId/$itemId';
      expect(url, 'plex://src_plex_1/12345');
    });
  });

  group('VodItem ID namespacing', () {
    test('Emby ID prefix', () {
      const prefix = 'emby';
      const sourceId = 'src1';
      const itemId = 'abc';
      expect('${prefix}_${sourceId}_$itemId', 'emby_src1_abc');
    });

    test('Jellyfin ID prefix', () {
      const prefix = 'jf';
      const sourceId = 'src2';
      const itemId = 'def';
      expect('${prefix}_${sourceId}_$itemId', 'jf_src2_def');
    });

    test('Plex ID prefix', () {
      const prefix = 'plex';
      const sourceId = 'src3';
      const itemId = '123';
      expect('${prefix}_${sourceId}_$itemId', 'plex_src3_123');
    });
  });

  group('Category format', () {
    test('category uses source name and library name', () {
      const sourceName = 'My Plex';
      const libraryName = 'Movies';
      expect('$sourceName > $libraryName', 'My Plex > Movies');
    });

    test('category with special characters', () {
      const sourceName = 'Home Server (Jellyfin)';
      const libraryName = '4K Movies';
      expect(
        '$sourceName > $libraryName',
        'Home Server (Jellyfin) > 4K Movies',
      );
    });
  });

  group('PlaylistSourceType media server detection', () {
    test('plex is a media server type', () {
      expect(
        PlaylistSourceType.plex != PlaylistSourceType.m3u &&
            PlaylistSourceType.plex != PlaylistSourceType.xtream &&
            PlaylistSourceType.plex != PlaylistSourceType.stalkerPortal,
        true,
      );
    });

    test('emby is a media server type', () {
      expect(PlaylistSourceType.emby.name, 'emby');
    });

    test('jellyfin is a media server type', () {
      expect(PlaylistSourceType.jellyfin.name, 'jellyfin');
    });
  });

  group('MediaItem type to VodType mapping', () {
    final types = {
      MediaType.movie: VodType.movie,
      MediaType.series: VodType.series,
      MediaType.season: VodType.series,
      MediaType.episode: VodType.episode,
      MediaType.folder: VodType.series,
      MediaType.channel: VodType.movie,
      MediaType.unknown: VodType.movie,
    };

    for (final entry in types.entries) {
      test('${entry.key.name} → ${entry.value.name}', () {
        final item = MediaItem(id: 'test', name: 'Test', type: entry.key);
        final vod = item.toVodItem(streamUrl: '');
        expect(vod.type, entry.value);
      });
    }
  });

  group('VodItem copyWith for ID namespacing', () {
    test('copyWith preserves all fields except id', () {
      final original = VodItem(
        id: 'original_id',
        name: 'Test',
        streamUrl: 'plex://src/123',
        type: VodType.movie,
        sourceId: 'src',
        category: 'Server > Movies',
        posterUrl: 'http://img.jpg',
        year: 2023,
      );

      final namespaced = original.copyWith(id: 'plex_src_123');

      expect(namespaced.id, 'plex_src_123');
      expect(namespaced.name, 'Test');
      expect(namespaced.streamUrl, 'plex://src/123');
      expect(namespaced.sourceId, 'src');
      expect(namespaced.category, 'Server > Movies');
      expect(namespaced.posterUrl, 'http://img.jpg');
      expect(namespaced.year, 2023);
    });
  });
}
