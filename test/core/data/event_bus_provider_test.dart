import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/data_change_event.dart';
import 'package:crispy_tivi/core/data/event_bus_provider.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

/// Build a [ProviderContainer] with [MemoryBackend] wired in.
ProviderContainer _makeContainer(MemoryBackend backend) {
  return ProviderContainer(
    overrides: [crispyBackendProvider.overrideWithValue(backend)],
  );
}

void main() {
  late MemoryBackend backend;
  late ProviderContainer container;

  setUp(() async {
    backend = MemoryBackend();
    await backend.init('');
    container = _makeContainer(backend);
  });

  tearDown(() => container.dispose());

  group('eventBusProvider', () {
    test('emits typed ChannelsUpdated from MemoryBackend', () async {
      final events = <DataChangeEvent>[];
      container.listen(eventBusProvider, (_, next) {
        if (next.hasValue) events.add(next.value!);
      }, fireImmediately: true);

      backend.emitTestEvent('{"type":"ChannelsUpdated","source_id":"src-1"}');
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, isA<ChannelsUpdated>());
      expect((events.first as ChannelsUpdated).sourceId, 'src-1');
    });

    test('emits typed WatchHistoryUpdated', () async {
      final events = <DataChangeEvent>[];
      container.listen(eventBusProvider, (_, next) {
        if (next.hasValue) events.add(next.value!);
      }, fireImmediately: true);

      backend.emitTestEvent(
        '{"type":"WatchHistoryUpdated","channel_id":"ch-99"}',
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      final event = events.first as WatchHistoryUpdated;
      expect(event.channelId, 'ch-99');
    });

    test('emits typed FavoriteToggled with fields', () async {
      final events = <DataChangeEvent>[];
      container.listen(eventBusProvider, (_, next) {
        if (next.hasValue) events.add(next.value!);
      }, fireImmediately: true);

      backend.emitTestEvent(
        '{"type":"FavoriteToggled","item_id":"ch5","is_favorite":true}',
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      final ft = events.first as FavoriteToggled;
      expect(ft.itemId, 'ch5');
      expect(ft.isFavorite, isTrue);
    });

    test(
      'malformed JSON falls back to BulkDataRefresh, does not crash',
      () async {
        final events = <DataChangeEvent>[];
        container.listen(eventBusProvider, (_, next) {
          if (next.hasValue) events.add(next.value!);
        }, fireImmediately: true);

        backend.emitTestEvent('{this is not valid json!!!');
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<BulkDataRefresh>());
      },
    );

    test('multiple events arrive in order', () async {
      final events = <DataChangeEvent>[];
      container.listen(eventBusProvider, (_, next) {
        if (next.hasValue) events.add(next.value!);
      }, fireImmediately: true);

      backend.emitTestEvent('{"type":"ChannelsUpdated","source_id":"first"}');
      backend.emitTestEvent('{"type":"BulkDataRefresh"}');
      backend.emitTestEvent(
        '{"type":"FavoriteToggled","item_id":"ch3","is_favorite":false}',
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(3));
      expect(events[0], isA<ChannelsUpdated>());
      expect(events[1], isA<BulkDataRefresh>());
      expect(events[2], isA<FavoriteToggled>());
    });

    test(
      'malformed event mid-stream does not poison subsequent events',
      () async {
        final events = <DataChangeEvent>[];
        container.listen(eventBusProvider, (_, next) {
          if (next.hasValue) events.add(next.value!);
        }, fireImmediately: true);

        backend.emitTestEvent('{"type":"SavedLayoutChanged"}');
        backend.emitTestEvent('CORRUPT');
        backend.emitTestEvent('{"type":"CloudSyncCompleted"}');
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(3));
        expect(events[0], isA<SavedLayoutChanged>());
        expect(events[1], isA<BulkDataRefresh>()); // fallback
        expect(events[2], isA<CloudSyncCompleted>());
      },
    );

    test(
      'unknown event type emits UnknownEvent (not BulkDataRefresh)',
      () async {
        final events = <DataChangeEvent>[];
        container.listen(eventBusProvider, (_, next) {
          if (next.hasValue) events.add(next.value!);
        }, fireImmediately: true);

        backend.emitTestEvent('{"type":"FutureUnknownEventType","data":"x"}');
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<UnknownEvent>());
        expect((events.first as UnknownEvent).type, 'FutureUnknownEventType');
      },
    );

    test('no events emitted before any emitTestEvent call', () async {
      final events = <DataChangeEvent>[];
      container.listen(eventBusProvider, (_, next) {
        if (next.hasValue) events.add(next.value!);
      }, fireImmediately: true);

      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
    });
  });
}
