import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/duplicate_group.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/channel_providers.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/duplicate_detection_service.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/iptv_service_providers.dart';
import 'package:crispy_tivi/features/iptv/presentation/providers/playlist_sync_service.dart';

void main() {
  group('PlaylistSyncService.detectDuplicates', () {
    late MemoryBackend backend;
    late ProviderContainer container;

    setUp(() async {
      backend = MemoryBackend();
      await backend.init('');
      container = ProviderContainer(
        overrides: [
          crispyBackendProvider.overrideWithValue(backend),
          channelListProvider.overrideWith(_TestChannelListNotifier.new),
          duplicateDetectionServiceProvider.overrideWithValue(
            _FakeDuplicateDetectionService(backend),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('keeps duplicate groups and duplicate ID readers aligned', () async {
      final service = container.read(playlistSyncServiceProvider);

      await service.detectDuplicates(const [
        Channel(id: 'ch-1', name: 'News 1', streamUrl: 'http://test/1'),
        Channel(id: 'ch-2', name: 'News 1 HD', streamUrl: 'http://test/1'),
        Channel(id: 'ch-3', name: 'Sports 1', streamUrl: 'http://test/2'),
        Channel(id: 'ch-4', name: 'Sports 1 Alt', streamUrl: 'http://test/2'),
      ]);

      expect(container.read(duplicateGroupsProvider), _duplicateGroups);
      expect(
        container.read(channelListProvider).duplicateIds,
        unorderedEquals({'ch-2', 'ch-4'}),
      );
      expect(container.read(duplicateCountProvider), 2);
      expect(container.read(isChannelDuplicateProvider('ch-2')), isTrue);
      expect(container.read(isChannelDuplicateProvider('ch-1')), isFalse);
    });
  });
}

const _duplicateGroups = [
  DuplicateGroup(streamUrl: 'http://test/1', channelIds: ['ch-1', 'ch-2']),
  DuplicateGroup(streamUrl: 'http://test/2', channelIds: ['ch-3', 'ch-4']),
];

class _TestChannelListNotifier extends ChannelListNotifier {
  @override
  ChannelListState build() => const ChannelListState();
}

class _FakeDuplicateDetectionService extends DuplicateDetectionService {
  _FakeDuplicateDetectionService(super.backend);

  @override
  Future<List<DuplicateGroup>> detectDuplicates(List<Channel> channels) async {
    return _duplicateGroups;
  }
}
