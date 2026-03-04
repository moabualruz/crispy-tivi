import 'dart:convert';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/features/iptv/data/datasources/'
    'channel_local_datasource.dart';
import 'package:crispy_tivi/features/iptv/data/models/'
    'channel_model.dart';
import 'package:crispy_tivi/features/iptv/data/repositories/'
    'channel_repository_impl.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/'
    'channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChannelLocalDatasource extends Mock
    implements ChannelLocalDatasource {}

class MockCrispyBackend extends Mock implements CrispyBackend {}

void main() {
  late MockChannelLocalDatasource mockDatasource;
  late MockCrispyBackend mockBackend;
  late ChannelRepositoryImpl repository;

  // ── Helpers ──────────────────────────────────────

  ChannelModel model({
    String id = 'ch1',
    String name = 'Test Channel',
    String streamUrl = 'http://example.com/s',
    int? number,
    String? group,
    bool isFavorite = false,
    String? sourceId,
  }) {
    return ChannelModel(
      id: id,
      name: name,
      streamUrl: streamUrl,
      number: number,
      group: group,
      isFavorite: isFavorite,
      sourceId: sourceId,
    );
  }

  Channel channel({
    String id = 'ch1',
    String name = 'Test Channel',
    String streamUrl = 'http://example.com/s',
    int? number,
    String? group,
    bool isFavorite = false,
  }) {
    return Channel(
      id: id,
      name: name,
      streamUrl: streamUrl,
      number: number,
      group: group,
      isFavorite: isFavorite,
    );
  }

  /// Stubs _sortChannels: backend returns the same
  /// JSON it receives (identity sort).
  void stubSortIdentity() {
    when(() => mockBackend.sortChannelsJson(any())).thenAnswer((inv) async {
      return inv.positionalArguments[0] as String;
    });
  }

  setUp(() {
    mockDatasource = MockChannelLocalDatasource();
    mockBackend = MockCrispyBackend();
    repository = ChannelRepositoryImpl(mockDatasource, mockBackend);
  });

  // ── getChannels ────────────────────────────────

  group('getChannels', () {
    test('returns sorted domain channels from '
        'datasource', () async {
      final models = [
        model(id: 'ch1', name: 'CNN'),
        model(id: 'ch2', name: 'ESPN'),
      ];
      when(() => mockDatasource.getAll()).thenReturn(models);
      stubSortIdentity();

      final result = await repository.getChannels();

      expect(result, hasLength(2));
      expect(result[0].id, 'ch1');
      expect(result[1].id, 'ch2');
      verify(() => mockDatasource.getAll()).called(1);
      verify(() => mockBackend.sortChannelsJson(any())).called(1);
    });

    test('returns empty list when datasource is empty', () async {
      when(() => mockDatasource.getAll()).thenReturn([]);

      final result = await repository.getChannels();

      expect(result, isEmpty);
      verifyNever(() => mockBackend.sortChannelsJson(any()));
    });

    test('maps all model fields to domain entities', () async {
      final models = [
        model(
          id: 'ch1',
          name: 'CNN',
          number: 42,
          group: 'News',
          isFavorite: true,
        ),
      ];
      when(() => mockDatasource.getAll()).thenReturn(models);
      stubSortIdentity();

      final result = await repository.getChannels();

      expect(result.first.name, 'CNN');
      expect(result.first.number, 42);
      expect(result.first.group, 'News');
      expect(result.first.isFavorite, isTrue);
    });
  });

  // ── getByGroup ─────────────────────────────────

  group('getByGroup', () {
    test('passes group to datasource and returns '
        'sorted results', () async {
      final models = [model(id: 'ch1', name: 'CNN', group: 'News')];
      when(() => mockDatasource.getAll(group: 'News')).thenReturn(models);
      stubSortIdentity();

      final result = await repository.getByGroup('News');

      expect(result, hasLength(1));
      expect(result.first.group, 'News');
      verify(() => mockDatasource.getAll(group: 'News')).called(1);
    });

    test('returns empty when group has no channels', () async {
      when(() => mockDatasource.getAll(group: 'Empty')).thenReturn([]);

      final result = await repository.getByGroup('Empty');

      expect(result, isEmpty);
    });

    test('delegates sort to backend', () async {
      final models = [model(id: 'a', name: 'A'), model(id: 'b', name: 'B')];
      when(() => mockDatasource.getAll(group: 'G')).thenReturn(models);
      stubSortIdentity();

      await repository.getByGroup('G');

      verify(() => mockBackend.sortChannelsJson(any())).called(1);
    });
  });

  // ── getGroups ──────────────────────────────────

  group('getGroups', () {
    test('delegates to datasource getAllGroups', () async {
      when(() => mockDatasource.getAllGroups()).thenReturn(['News', 'Sports']);

      final result = await repository.getGroups();

      expect(result, ['News', 'Sports']);
      verify(() => mockDatasource.getAllGroups()).called(1);
    });

    test('returns empty list when no groups', () async {
      when(() => mockDatasource.getAllGroups()).thenReturn([]);

      final result = await repository.getGroups();

      expect(result, isEmpty);
    });

    test('returns sorted groups from datasource', () async {
      when(() => mockDatasource.getAllGroups()).thenReturn(['A', 'B', 'C']);

      final result = await repository.getGroups();

      expect(result, ['A', 'B', 'C']);
    });
  });

  // ── search ─────────────────────────────────────

  group('search', () {
    test('delegates query to datasource and maps '
        'results', () async {
      final models = [model(id: 'ch1', name: 'CNN')];
      when(() => mockDatasource.search('CNN')).thenReturn(models);

      final result = await repository.search('CNN');

      expect(result, hasLength(1));
      expect(result.first.name, 'CNN');
      verify(() => mockDatasource.search('CNN')).called(1);
    });

    test('does not sort search results', () async {
      when(() => mockDatasource.search('x')).thenReturn([]);

      await repository.search('x');

      verifyNever(() => mockBackend.sortChannelsJson(any()));
    });

    test('returns empty for no matches', () async {
      when(() => mockDatasource.search('zzz')).thenReturn([]);

      final result = await repository.search('zzz');

      expect(result, isEmpty);
    });
  });

  // ── getFavorites ───────────────────────────────

  group('getFavorites', () {
    test('returns sorted favorite channels', () async {
      final models = [model(id: 'ch1', name: 'Fav1', isFavorite: true)];
      when(() => mockDatasource.getFavorites()).thenReturn(models);
      stubSortIdentity();

      final result = await repository.getFavorites();

      expect(result, hasLength(1));
      expect(result.first.isFavorite, isTrue);
      verify(() => mockDatasource.getFavorites()).called(1);
    });

    test('returns empty when no favorites', () async {
      when(() => mockDatasource.getFavorites()).thenReturn([]);

      final result = await repository.getFavorites();

      expect(result, isEmpty);
    });

    test('skips sort when favorites list is empty', () async {
      when(() => mockDatasource.getFavorites()).thenReturn([]);

      await repository.getFavorites();

      verifyNever(() => mockBackend.sortChannelsJson(any()));
    });
  });

  // ── toggleFavorite ─────────────────────────────

  group('toggleFavorite', () {
    test('returns updated domain channel on success', () async {
      final updated = model(id: 'ch1', name: 'CNN', isFavorite: true);
      when(() => mockDatasource.toggleFavorite('ch1')).thenReturn(updated);

      final result = await repository.toggleFavorite('ch1');

      expect(result.id, 'ch1');
      expect(result.isFavorite, isTrue);
    });

    test('throws StateError when channel not found', () async {
      when(() => mockDatasource.toggleFavorite('missing')).thenReturn(null);

      expect(() => repository.toggleFavorite('missing'), throwsStateError);
    });

    test('error message contains channel id', () async {
      when(() => mockDatasource.toggleFavorite('abc')).thenReturn(null);

      expect(
        () => repository.toggleFavorite('abc'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('abc'),
          ),
        ),
      );
    });
  });

  // ── getById ────────────────────────────────────

  group('getById', () {
    test('returns domain channel when found', () async {
      when(
        () => mockDatasource.findById('ch1'),
      ).thenReturn(model(id: 'ch1', name: 'CNN'));

      final result = await repository.getById('ch1');

      expect(result, isNotNull);
      expect(result!.name, 'CNN');
    });

    test('returns null when channel not found', () async {
      when(() => mockDatasource.findById('missing')).thenReturn(null);

      final result = await repository.getById('missing');

      expect(result, isNull);
    });

    test('delegates to datasource findById', () async {
      when(() => mockDatasource.findById('ch1')).thenReturn(null);

      await repository.getById('ch1');

      verify(() => mockDatasource.findById('ch1')).called(1);
    });
  });

  // ── saveChannels ───────────────────────────────

  group('saveChannels', () {
    test('converts domain channels to models and '
        'saves via datasource', () async {
      final channels = [
        channel(id: 'ch1', name: 'CNN'),
        channel(id: 'ch2', name: 'ESPN'),
      ];
      when(() => mockDatasource.putAll(any())).thenReturn(null);

      await repository.saveChannels(channels);

      final captured =
          verify(() => mockDatasource.putAll(captureAny())).captured.single
              as List<ChannelModel>;
      expect(captured, hasLength(2));
      expect(captured[0].id, 'ch1');
      expect(captured[1].id, 'ch2');
    });

    test('passes sourceId to fromDomain', () async {
      final channels = [channel(id: 'ch1', name: 'CNN')];
      when(() => mockDatasource.putAll(any())).thenReturn(null);

      await repository.saveChannels(channels, sourceId: 'src42');

      final captured =
          verify(() => mockDatasource.putAll(captureAny())).captured.single
              as List<ChannelModel>;
      expect(captured.first.sourceId, 'src42');
    });

    test('handles empty channel list', () async {
      when(() => mockDatasource.putAll(any())).thenReturn(null);

      await repository.saveChannels([]);

      final captured =
          verify(() => mockDatasource.putAll(captureAny())).captured.single
              as List<ChannelModel>;
      expect(captured, isEmpty);
    });

    test('sourceId is null when not provided', () async {
      final channels = [channel(id: 'ch1', name: 'CNN')];
      when(() => mockDatasource.putAll(any())).thenReturn(null);

      await repository.saveChannels(channels);

      final captured =
          verify(() => mockDatasource.putAll(captureAny())).captured.single
              as List<ChannelModel>;
      expect(captured.first.sourceId, isNull);
    });
  });

  // ── _sortChannels (tested through public API) ──

  group('sort delegation', () {
    test('sends channel JSON to backend for sorting', () async {
      final models = [
        model(id: 'ch1', name: 'B', number: 2),
        model(id: 'ch2', name: 'A', number: 1),
      ];
      when(() => mockDatasource.getAll()).thenReturn(models);
      stubSortIdentity();

      await repository.getChannels();

      final captured =
          verify(
                () => mockBackend.sortChannelsJson(captureAny()),
              ).captured.single
              as String;
      final decoded = jsonDecode(captured) as List;
      expect(decoded, hasLength(2));
    });

    test('skips sort for empty channel list', () async {
      when(() => mockDatasource.getAll()).thenReturn([]);

      await repository.getChannels();

      verifyNever(() => mockBackend.sortChannelsJson(any()));
    });

    test('parses sorted JSON back to channels', () async {
      final models = [model(id: 'ch1', name: 'Z')];
      when(() => mockDatasource.getAll()).thenReturn(models);

      // Return a specific sorted JSON
      final sortedJson = jsonEncode([
        channelToMap(channel(id: 'ch1', name: 'Z')),
      ]);
      when(
        () => mockBackend.sortChannelsJson(any()),
      ).thenAnswer((_) async => sortedJson);

      final result = await repository.getChannels();

      expect(result, hasLength(1));
      expect(result.first.id, 'ch1');
    });
  });
}
