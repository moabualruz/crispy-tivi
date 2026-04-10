import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/epg/presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/playlist_sync_service.dart';
import 'package:crispy_tivi/features/profiles/data/source_access_service.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';

void main() {
  group('PlaylistSyncService.loadFromCache', () {
    late MemoryBackend backend;
    late ProviderContainer container;

    setUp(() async {
      backend = MemoryBackend();
      await backend.init('');
      container = ProviderContainer(
        overrides: [
          crispyBackendProvider.overrideWithValue(backend),
          accessibleSourcesProvider.overrideWith((ref) async => null),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('hydrates cached channels, VOD, and EPG into UI providers', () async {
      final cache = container.read(cacheServiceProvider);
      final now = DateTime.now().toUtc();

      const channel = Channel(
        id: 'ch-1',
        name: 'News 24',
        streamUrl: 'http://example.com/live',
        group: 'News',
        tvgId: 'news24',
        sourceId: 'src-1',
      );
      final vod = VodItem(
        id: 'vod-1',
        name: 'Example Movie',
        streamUrl: 'http://example.com/movie.mp4',
        type: VodType.movie,
        category: 'Drama',
        sourceId: 'src-1',
      );
      final epgEntry = EpgEntry(
        channelId: channel.id,
        title: 'Morning News',
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now.add(const Duration(minutes: 30)),
        sourceId: 'src-1',
      );

      await cache.saveChannels([channel]);
      await cache.saveVodItems([vod]);
      await cache.saveEpgEntries({
        channel.id: [epgEntry],
      });

      final service = container.read(playlistSyncServiceProvider);
      await service.loadFromCache();

      expect(container.read(vodProvider).items, hasLength(1));
      expect(container.read(epgProvider).channels, hasLength(1));
      expect(
        container.read(epgProvider).entries[channel.id]?.first.title,
        'Morning News',
      );
    });
  });
}
