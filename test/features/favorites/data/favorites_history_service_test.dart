import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/favorites/data/favorites_history_service.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';

void main() {
  late ProviderContainer container;
  late FavoritesHistoryService service;

  setUp(() {
    container = ProviderContainer();
    service = container.read(favoritesHistoryProvider.notifier);
  });

  tearDown(() => container.dispose());

  FavoritesHistoryState readState() => container.read(favoritesHistoryProvider);

  Channel makeChannel(String id) =>
      Channel(id: id, name: 'Channel $id', streamUrl: 'http://example.com/$id');

  group('FavoritesHistoryService', () {
    test('starts with empty history', () {
      expect(readState().recentlyWatched, isEmpty);
      expect(readState().lastChannelId, isNull);
    });

    test('addToHistory adds a channel', () {
      service.addToHistory(makeChannel('ch1'));
      expect(readState().recentlyWatched.length, 1);
      expect(readState().lastChannelId, 'ch1');
    });

    test('addToHistory keeps most-recent first', () {
      service.addToHistory(makeChannel('ch1'));
      service.addToHistory(makeChannel('ch2'));
      expect(readState().recentlyWatched.first.id, 'ch2');
    });

    test('addToHistory deduplicates by id', () {
      service.addToHistory(makeChannel('ch1'));
      service.addToHistory(makeChannel('ch2'));
      service.addToHistory(makeChannel('ch1'));
      expect(readState().recentlyWatched.length, 2);
      expect(readState().recentlyWatched.first.id, 'ch1');
    });

    test('addToHistory caps at 50 items', () {
      for (var i = 0; i < 55; i++) {
        service.addToHistory(makeChannel('ch_$i'));
      }
      expect(readState().recentlyWatched.length, 50);
    });

    test('saveWatchPosition stores position', () {
      service.saveWatchPosition(
        'vod1',
        const Duration(minutes: 30),
        const Duration(hours: 2),
      );
      final pos = service.getWatchPosition('vod1');
      expect(pos, isNotNull);
      expect(pos!.position, const Duration(minutes: 30));
      expect(pos.total, const Duration(hours: 2));
    });

    test('getWatchPosition returns null for unknown', () {
      expect(service.getWatchPosition('unknown'), isNull);
    });

    test('watchPosition progress calculates correctly', () {
      service.saveWatchPosition(
        'vod1',
        const Duration(minutes: 60),
        const Duration(minutes: 120),
      );
      final pos = service.getWatchPosition('vod1')!;
      expect(pos.progress, closeTo(0.5, 0.01));
      expect(pos.isCompleted, isFalse);
    });

    test('continueWatching lists incomplete items', () {
      service.saveWatchPosition(
        'vod1',
        const Duration(minutes: 30),
        const Duration(hours: 2),
      );
      service.saveWatchPosition(
        'vod2',
        const Duration(hours: 1, minutes: 55),
        const Duration(hours: 2),
      );
      // vod2 is >90% so considered completed.
      expect(readState().continueWatching, contains('vod1'));
      expect(readState().continueWatching, isNot(contains('vod2')));
    });

    test('clearHistory removes all data', () {
      service.addToHistory(makeChannel('ch1'));
      service.saveWatchPosition(
        'vod1',
        const Duration(minutes: 30),
        const Duration(hours: 2),
      );
      service.clearHistory();
      expect(readState().recentlyWatched, isEmpty);
      expect(readState().watchPositions, isEmpty);
    });

    test('removeFromHistory removes specific channel', () {
      service.addToHistory(makeChannel('ch1'));
      service.addToHistory(makeChannel('ch2'));
      service.removeFromHistory('ch1');
      expect(readState().recentlyWatched.length, 1);
      expect(readState().recentlyWatched.first.id, 'ch2');
    });
  });
}
