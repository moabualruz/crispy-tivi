import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/player/presentation/providers/playback_session_provider.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/player_queue_overlay.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueueItem', () {
    test('equality by id', () {
      const a = QueueItem(id: '1', title: 'A', streamUrl: 'url1');
      const b = QueueItem(id: '1', title: 'B', streamUrl: 'url2');
      const c = QueueItem(id: '2', title: 'A', streamUrl: 'url1');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode based on id', () {
      const a = QueueItem(id: '1', title: 'A', streamUrl: 'url1');
      const b = QueueItem(id: '1', title: 'B', streamUrl: 'url2');
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('QueueNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty and hidden', () {
      final state = container.read(queueProvider);
      expect(state.items, isEmpty);
      expect(state.currentIndex, 0);
      expect(state.isVisible, isFalse);
      expect(state.label, 'Up Next');
    });

    test('setQueue populates items and label', () {
      const items = [
        QueueItem(id: '1', title: 'Ep 1', streamUrl: 'url1'),
        QueueItem(id: '2', title: 'Ep 2', streamUrl: 'url2'),
        QueueItem(id: '3', title: 'Ep 3', streamUrl: 'url3'),
      ];
      container
          .read(queueProvider.notifier)
          .setQueue(items: items, currentIndex: 1, label: 'Season 1');

      final state = container.read(queueProvider);
      expect(state.items.length, 3);
      expect(state.currentIndex, 1);
      expect(state.label, 'Season 1');
    });

    test('clear resets to default', () {
      container
          .read(queueProvider.notifier)
          .setQueue(
            items: const [QueueItem(id: '1', title: 'Ep 1', streamUrl: 'url1')],
            label: 'Test',
          );
      container.read(queueProvider.notifier).clear();

      final state = container.read(queueProvider);
      expect(state.items, isEmpty);
      expect(state.currentIndex, 0);
      expect(state.label, 'Up Next');
    });

    test('toggleVisibility flips isVisible', () {
      expect(container.read(queueProvider).isVisible, isFalse);
      container.read(queueProvider.notifier).toggleVisibility();
      expect(container.read(queueProvider).isVisible, isTrue);
      container.read(queueProvider.notifier).toggleVisibility();
      expect(container.read(queueProvider).isVisible, isFalse);
    });

    test('show and hide', () {
      container.read(queueProvider.notifier).show();
      expect(container.read(queueProvider).isVisible, isTrue);
      container.read(queueProvider.notifier).hide();
      expect(container.read(queueProvider).isVisible, isFalse);
    });

    test('advance increments currentIndex', () {
      container
          .read(queueProvider.notifier)
          .setQueue(
            items: const [
              QueueItem(id: '1', title: 'Ep 1', streamUrl: 'url1'),
              QueueItem(id: '2', title: 'Ep 2', streamUrl: 'url2'),
              QueueItem(id: '3', title: 'Ep 3', streamUrl: 'url3'),
            ],
          );

      expect(container.read(queueProvider).currentIndex, 0);
      container.read(queueProvider.notifier).advance();
      expect(container.read(queueProvider).currentIndex, 1);
      container.read(queueProvider.notifier).advance();
      expect(container.read(queueProvider).currentIndex, 2);
    });

    test('advance does not go past last item', () {
      container
          .read(queueProvider.notifier)
          .setQueue(
            items: const [QueueItem(id: '1', title: 'Ep 1', streamUrl: 'url1')],
          );

      container.read(queueProvider.notifier).advance();
      expect(container.read(queueProvider).currentIndex, 0);
    });
  });

  group('populateFromSession', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('episodes mapped to QueueItems with subtitle', () {
      final episodes = [
        const VodItem(
          id: 'e1',
          name: 'Pilot',
          streamUrl: 'http://ep1.ts',
          type: VodType.episode,
          episodeNumber: 1,
          duration: 45,
          posterUrl: 'http://poster1.jpg',
        ),
        const VodItem(
          id: 'e2',
          name: 'The Return',
          streamUrl: 'http://ep2.ts',
          type: VodType.episode,
          episodeNumber: 2,
          duration: 50,
        ),
      ];

      container
          .read(queueProvider.notifier)
          .populateFromSession(
            PlaybackSessionState(
              streamUrl: 'http://ep1.ts',
              mediaType: 'episode',
              seasonNumber: 1,
              episodeNumber: 1,
              episodeList: episodes,
            ),
          );

      final state = container.read(queueProvider);
      expect(state.items.length, 2);
      expect(state.items[0].id, 'e1');
      expect(state.items[0].title, 'Pilot');
      expect(state.items[0].streamUrl, 'http://ep1.ts');
      expect(state.items[0].subtitle, 'Episode 1');
      expect(state.items[0].duration, const Duration(minutes: 45));
      expect(state.items[0].thumbnailUrl, 'http://poster1.jpg');
      expect(state.items[1].id, 'e2');
      expect(state.items[1].subtitle, 'Episode 2');
      expect(state.items[1].thumbnailUrl, isNull);
      expect(state.currentIndex, 0);
      expect(state.label, 'Season 1 Episodes');
    });

    test('current episode index found by stream URL', () {
      final episodes = [
        const VodItem(
          id: 'e1',
          name: 'Ep 1',
          streamUrl: 'http://ep1.ts',
          type: VodType.episode,
          episodeNumber: 1,
        ),
        const VodItem(
          id: 'e2',
          name: 'Ep 2',
          streamUrl: 'http://ep2.ts',
          type: VodType.episode,
          episodeNumber: 2,
        ),
        const VodItem(
          id: 'e3',
          name: 'Ep 3',
          streamUrl: 'http://ep3.ts',
          type: VodType.episode,
          episodeNumber: 3,
        ),
      ];

      container
          .read(queueProvider.notifier)
          .populateFromSession(
            PlaybackSessionState(
              streamUrl: 'http://ep2.ts',
              mediaType: 'episode',
              seasonNumber: 2,
              episodeNumber: 2,
              episodeList: episodes,
            ),
          );

      expect(container.read(queueProvider).currentIndex, 1);
    });

    test('current episode index found by episode number fallback', () {
      final episodes = [
        const VodItem(
          id: 'e1',
          name: 'Ep 1',
          streamUrl: 'http://ep1.ts',
          type: VodType.episode,
          episodeNumber: 1,
        ),
        const VodItem(
          id: 'e2',
          name: 'Ep 2',
          streamUrl: 'http://ep2.ts',
          type: VodType.episode,
          episodeNumber: 2,
        ),
      ];

      container
          .read(queueProvider.notifier)
          .populateFromSession(
            PlaybackSessionState(
              // URL doesn't match any episode.
              streamUrl: 'http://resolved-ep2.ts',
              mediaType: 'episode',
              episodeNumber: 2,
              episodeList: episodes,
            ),
          );

      expect(container.read(queueProvider).currentIndex, 1);
    });

    test('channels mapped to QueueItems', () {
      final channels = [
        const Channel(
          id: 'c1',
          name: 'BBC One',
          streamUrl: 'http://bbc1.ts',
          logoUrl: 'http://bbc1.png',
          group: 'UK News',
        ),
        const Channel(
          id: 'c2',
          name: 'CNN',
          streamUrl: 'http://cnn.ts',
          group: 'US News',
        ),
      ];

      container
          .read(queueProvider.notifier)
          .populateFromSession(
            PlaybackSessionState(
              streamUrl: 'http://bbc1.ts',
              isLive: true,
              channelList: channels,
              channelIndex: 0,
            ),
          );

      final state = container.read(queueProvider);
      expect(state.items.length, 2);
      expect(state.items[0].id, 'c1');
      expect(state.items[0].title, 'BBC One');
      expect(state.items[0].streamUrl, 'http://bbc1.ts');
      expect(state.items[0].thumbnailUrl, 'http://bbc1.png');
      expect(state.items[0].subtitle, 'UK News');
      expect(state.items[1].id, 'c2');
      expect(state.items[1].subtitle, 'US News');
      expect(state.currentIndex, 0);
      expect(state.label, 'Channels');
    });

    test('channel index preserved from session', () {
      final channels = [
        const Channel(id: 'c1', name: 'Ch 1', streamUrl: 'http://c1.ts'),
        const Channel(id: 'c2', name: 'Ch 2', streamUrl: 'http://c2.ts'),
        const Channel(id: 'c3', name: 'Ch 3', streamUrl: 'http://c3.ts'),
      ];

      container
          .read(queueProvider.notifier)
          .populateFromSession(
            PlaybackSessionState(
              streamUrl: 'http://c2.ts',
              isLive: true,
              channelList: channels,
              channelIndex: 1,
            ),
          );

      expect(container.read(queueProvider).currentIndex, 1);
    });

    test('empty session clears queue', () {
      // Pre-populate queue.
      container
          .read(queueProvider.notifier)
          .setQueue(
            items: const [QueueItem(id: '1', title: 'X', streamUrl: 'url')],
          );
      expect(container.read(queueProvider).items, isNotEmpty);

      // Populate with empty session.
      container
          .read(queueProvider.notifier)
          .populateFromSession(const PlaybackSessionState());
      expect(container.read(queueProvider).items, isEmpty);
    });

    test('episode without season number uses generic label', () {
      final episodes = [
        const VodItem(
          id: 'e1',
          name: 'Ep 1',
          streamUrl: 'http://ep1.ts',
          type: VodType.episode,
        ),
      ];

      container
          .read(queueProvider.notifier)
          .populateFromSession(
            PlaybackSessionState(
              streamUrl: 'http://ep1.ts',
              mediaType: 'episode',
              episodeList: episodes,
            ),
          );

      expect(container.read(queueProvider).label, 'Episodes');
    });

    test('episode without episodeNumber has null subtitle', () {
      final episodes = [
        const VodItem(
          id: 'e1',
          name: 'Unnamed Episode',
          streamUrl: 'http://ep.ts',
          type: VodType.episode,
        ),
      ];

      container
          .read(queueProvider.notifier)
          .populateFromSession(
            PlaybackSessionState(
              streamUrl: 'http://ep.ts',
              episodeList: episodes,
            ),
          );

      expect(container.read(queueProvider).items[0].subtitle, isNull);
    });
  });

  group('QueueState', () {
    test('copyWith preserves unchanged fields', () {
      const original = QueueState(
        items: [QueueItem(id: '1', title: 'A', streamUrl: 'url')],
        currentIndex: 0,
        isVisible: true,
        label: 'Test',
      );
      final copy = original.copyWith(isVisible: false);
      expect(copy.items.length, 1);
      expect(copy.currentIndex, 0);
      expect(copy.isVisible, isFalse);
      expect(copy.label, 'Test');
    });
  });
}
