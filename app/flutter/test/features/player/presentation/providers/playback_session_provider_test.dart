import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';

// ─── Mocks ───────────────────────────────────────────────────

class MockPlayerService extends Mock implements PlayerService {}

// ─── Helpers ─────────────────────────────────────────────────

const _streamUrl = 'http://example.com/stream.m3u8';
const _streamUrl2 = 'http://example.com/other.m3u8';

Channel _makeChannel(String id, String url) =>
    Channel(id: id, name: 'Channel $id', streamUrl: url);

VodItem _makeEpisode({
  required String id,
  int? episodeNumber,
  String? seriesId,
}) => VodItem(
  id: id,
  name: 'Episode $id',
  streamUrl: 'http://example.com/ep$id.mp4',
  type: VodType.episode,
  episodeNumber: episodeNumber,
  seriesId: seriesId,
);

ProviderContainer _makeContainer(MockPlayerService mockSvc) {
  return ProviderContainer(
    overrides: [
      playerServiceProvider.overrideWithValue(mockSvc),
      cacheServiceProvider.overrideWithValue(CacheService(MemoryBackend())),
    ],
  );
}

void main() {
  late MockPlayerService mockPlayerService;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockPlayerService = MockPlayerService();
    when(
      () => mockPlayerService.play(
        any(),
        isLive: any(named: 'isLive'),
        channelName: any(named: 'channelName'),
        channelLogoUrl: any(named: 'channelLogoUrl'),
        currentProgram: any(named: 'currentProgram'),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockPlayerService.setSpeed(any())).thenAnswer((_) async {});
    when(() => mockPlayerService.forceStateEmit()).thenReturn(null);
  });

  // ── PlaybackSessionState ──────────────────────────────────

  group('PlaybackSessionState defaults', () {
    test('streamUrl defaults to empty string', () {
      const state = PlaybackSessionState();
      expect(state.streamUrl, '');
    });

    test('isLive defaults to false', () {
      const state = PlaybackSessionState();
      expect(state.isLive, isFalse);
    });

    test('channelIndex defaults to 0', () {
      const state = PlaybackSessionState();
      expect(state.channelIndex, 0);
    });

    test('all optional fields default to null', () {
      const state = PlaybackSessionState();
      expect(state.channelName, isNull);
      expect(state.channelLogoUrl, isNull);
      expect(state.currentProgram, isNull);
      expect(state.headers, isNull);
      expect(state.channelList, isNull);
      expect(state.startPosition, isNull);
      expect(state.mediaType, isNull);
      expect(state.seriesId, isNull);
      expect(state.seasonNumber, isNull);
      expect(state.episodeNumber, isNull);
      expect(state.episodeList, isNull);
      expect(state.posterUrl, isNull);
      expect(state.seriesPosterUrl, isNull);
    });
  });

  group('PlaybackSessionState.copyWith', () {
    test('copyWith replaces streamUrl', () {
      const state = PlaybackSessionState(streamUrl: 'http://old.com/s.m3u8');
      final copy = state.copyWith(streamUrl: _streamUrl);
      expect(copy.streamUrl, _streamUrl);
    });

    test('copyWith preserves unchanged fields', () {
      const state = PlaybackSessionState(
        streamUrl: _streamUrl,
        isLive: true,
        channelName: 'BBC One',
        channelIndex: 3,
      );
      final copy = state.copyWith(channelIndex: 5);
      expect(copy.streamUrl, _streamUrl);
      expect(copy.isLive, isTrue);
      expect(copy.channelName, 'BBC One');
      expect(copy.channelIndex, 5);
    });

    test('copyWith replaces multiple fields at once', () {
      const state = PlaybackSessionState();
      final copy = state.copyWith(
        streamUrl: _streamUrl,
        isLive: true,
        channelName: 'CNN',
        channelLogoUrl: 'http://logos.com/cnn.png',
        mediaType: 'live',
      );
      expect(copy.streamUrl, _streamUrl);
      expect(copy.isLive, isTrue);
      expect(copy.channelName, 'CNN');
      expect(copy.channelLogoUrl, 'http://logos.com/cnn.png');
      expect(copy.mediaType, 'live');
    });

    test('copyWith replaces headers map', () {
      const state = PlaybackSessionState();
      final headers = {'User-Agent': 'TestAgent/1.0'};
      final copy = state.copyWith(headers: headers);
      expect(copy.headers, headers);
    });

    test('copyWith replaces episodeList', () {
      final ep1 = _makeEpisode(id: 'e1', episodeNumber: 1);
      final ep2 = _makeEpisode(id: 'e2', episodeNumber: 2);
      const state = PlaybackSessionState();
      final copy = state.copyWith(episodeList: [ep1, ep2]);
      expect(copy.episodeList, hasLength(2));
      expect(copy.episodeList!.first.id, 'e1');
    });
  });

  // ── PlaybackSessionNotifier initial state ─────────────────

  group('PlaybackSessionNotifier initial state', () {
    test('initial state is empty PlaybackSessionState', () {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      final state = container.read(playbackSessionProvider);
      expect(state.streamUrl, '');
      expect(state.isLive, isFalse);
      expect(state.channelName, isNull);
    });
  });

  // ── startPreview ──────────────────────────────────────────

  group('PlaybackSessionNotifier.startPreview', () {
    test('should update state metadata without calling playerService.play', () {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      container
          .read(playbackSessionProvider.notifier)
          .startPreview(
            streamUrl: _streamUrl,
            isLive: true,
            channelName: 'Live Channel',
          );

      final state = container.read(playbackSessionProvider);
      expect(state.streamUrl, _streamUrl);
      expect(state.isLive, isTrue);
      expect(state.channelName, 'Live Channel');

      // playerService.play must NOT be called for preview.
      verifyNever(
        () => mockPlayerService.play(
          any(),
          isLive: any(named: 'isLive'),
          channelName: any(named: 'channelName'),
          channelLogoUrl: any(named: 'channelLogoUrl'),
          currentProgram: any(named: 'currentProgram'),
          headers: any(named: 'headers'),
        ),
      );
    });

    test('should persist all metadata fields in preview state', () {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      final ch1 = _makeChannel('ch1', 'http://ch1.com/s.m3u8');
      final ch2 = _makeChannel('ch2', 'http://ch2.com/s.m3u8');

      container
          .read(playbackSessionProvider.notifier)
          .startPreview(
            streamUrl: _streamUrl,
            isLive: true,
            channelName: 'My Channel',
            channelLogoUrl: 'http://logos.com/logo.png',
            currentProgram: 'Evening News',
            headers: {'User-Agent': 'myapp'},
            channelList: [ch1, ch2],
            channelIndex: 1,
            mediaType: 'live',
            seriesId: null,
            seasonNumber: null,
            episodeNumber: null,
          );

      final state = container.read(playbackSessionProvider);
      expect(state.channelLogoUrl, 'http://logos.com/logo.png');
      expect(state.currentProgram, 'Evening News');
      expect(state.headers, {'User-Agent': 'myapp'});
      expect(state.channelList, hasLength(2));
      expect(state.channelIndex, 1);
      expect(state.mediaType, 'live');
    });

    test('should update state for VOD episode preview', () {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      final ep1 = _makeEpisode(id: 'e1', episodeNumber: 1, seriesId: 's1');
      final ep2 = _makeEpisode(id: 'e2', episodeNumber: 2, seriesId: 's1');

      container
          .read(playbackSessionProvider.notifier)
          .startPreview(
            streamUrl: _streamUrl,
            isLive: false,
            channelName: 'Breaking Bad — S01E01',
            mediaType: 'episode',
            seriesId: 's1',
            seasonNumber: 1,
            episodeNumber: 1,
            episodeList: [ep1, ep2],
            posterUrl: 'http://images.com/ep1.jpg',
            seriesPosterUrl: 'http://images.com/series.jpg',
            startPosition: const Duration(minutes: 5),
          );

      final state = container.read(playbackSessionProvider);
      expect(state.isLive, isFalse);
      expect(state.seriesId, 's1');
      expect(state.seasonNumber, 1);
      expect(state.episodeNumber, 1);
      expect(state.episodeList, hasLength(2));
      expect(state.startPosition, const Duration(minutes: 5));
      expect(state.posterUrl, 'http://images.com/ep1.jpg');
      expect(state.seriesPosterUrl, 'http://images.com/series.jpg');
    });
  });

  // ── startPlayback ─────────────────────────────────────────

  group('PlaybackSessionNotifier.startPlayback', () {
    test('should update state and call playerService.play', () async {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      // Stub enterFullscreen so it doesn't throw.
      await container
          .read(playbackSessionProvider.notifier)
          .startPlayback(streamUrl: _streamUrl, isLive: true);

      final state = container.read(playbackSessionProvider);
      expect(state.streamUrl, _streamUrl);
      expect(state.isLive, isTrue);

      verify(
        () => mockPlayerService.play(
          _streamUrl,
          isLive: true,
          channelName: null,
          channelLogoUrl: null,
          currentProgram: null,
          headers: null,
        ),
      ).called(1);
    });

    test('should pass channel metadata to playerService.play', () async {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      await container
          .read(playbackSessionProvider.notifier)
          .startPlayback(
            streamUrl: _streamUrl,
            isLive: true,
            channelName: 'BBC One',
            channelLogoUrl: 'http://logos.com/bbc.png',
            currentProgram: 'Top Gear',
            headers: {'User-Agent': 'crispy'},
          );

      verify(
        () => mockPlayerService.play(
          _streamUrl,
          isLive: true,
          channelName: 'BBC One',
          channelLogoUrl: 'http://logos.com/bbc.png',
          currentProgram: 'Top Gear',
          headers: {'User-Agent': 'crispy'},
        ),
      ).called(1);
    });

    test('should persist session metadata in state', () async {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      final ch1 = _makeChannel('ch1', 'http://ch1.com/live.m3u8');
      final ch2 = _makeChannel('ch2', 'http://ch2.com/live.m3u8');

      await container
          .read(playbackSessionProvider.notifier)
          .startPlayback(
            streamUrl: _streamUrl,
            isLive: true,
            channelList: [ch1, ch2],
            channelIndex: 1,
            mediaType: 'live',
          );

      final state = container.read(playbackSessionProvider);
      expect(state.channelList, hasLength(2));
      expect(state.channelIndex, 1);
      expect(state.mediaType, 'live');
    });
  });

  // ── updateChannelIndex ────────────────────────────────────

  group('PlaybackSessionNotifier.updateChannelIndex', () {
    test('should update only channelIndex and preserve all other fields', () {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      container
          .read(playbackSessionProvider.notifier)
          .startPreview(
            streamUrl: _streamUrl,
            isLive: true,
            channelName: 'Channel A',
            channelIndex: 0,
          );

      container.read(playbackSessionProvider.notifier).updateChannelIndex(5);

      final state = container.read(playbackSessionProvider);
      expect(state.channelIndex, 5);
      // Other fields must be preserved.
      expect(state.streamUrl, _streamUrl);
      expect(state.channelName, 'Channel A');
    });

    test('should allow channelIndex of 0', () {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      container
          .read(playbackSessionProvider.notifier)
          .startPreview(streamUrl: _streamUrl, channelIndex: 7);
      container.read(playbackSessionProvider.notifier).updateChannelIndex(0);

      expect(container.read(playbackSessionProvider).channelIndex, 0);
    });
  });

  // ── clearSession ──────────────────────────────────────────

  group('PlaybackSessionNotifier.clearSession', () {
    test('should reset state to empty PlaybackSessionState', () {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      container
          .read(playbackSessionProvider.notifier)
          .startPreview(
            streamUrl: _streamUrl,
            isLive: true,
            channelName: 'Live TV',
            channelIndex: 3,
          );

      container.read(playbackSessionProvider.notifier).clearSession();

      final state = container.read(playbackSessionProvider);
      expect(state.streamUrl, '');
      expect(state.isLive, isFalse);
      expect(state.channelName, isNull);
      expect(state.channelIndex, 0);
    });

    test('should clear session even when no session was started', () {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      // Should not throw.
      container.read(playbackSessionProvider.notifier).clearSession();
      final state = container.read(playbackSessionProvider);
      expect(state.streamUrl, '');
    });
  });

  // ── Multiple session updates ──────────────────────────────

  group('sequential session updates', () {
    test('startPreview twice overwrites previous session', () {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      container
          .read(playbackSessionProvider.notifier)
          .startPreview(
            streamUrl: _streamUrl,
            isLive: true,
            channelName: 'First Channel',
          );
      container
          .read(playbackSessionProvider.notifier)
          .startPreview(
            streamUrl: _streamUrl2,
            isLive: false,
            channelName: 'Second Channel',
          );

      final state = container.read(playbackSessionProvider);
      expect(state.streamUrl, _streamUrl2);
      expect(state.isLive, isFalse);
      expect(state.channelName, 'Second Channel');
    });

    test('updateChannelIndex after clearSession resets to '
        'new index from baseline 0', () {
      final container = _makeContainer(mockPlayerService);
      addTearDown(container.dispose);

      container
          .read(playbackSessionProvider.notifier)
          .startPreview(streamUrl: _streamUrl, channelIndex: 10);
      container.read(playbackSessionProvider.notifier).clearSession();
      container.read(playbackSessionProvider.notifier).updateChannelIndex(2);

      expect(container.read(playbackSessionProvider).channelIndex, 2);
      expect(container.read(playbackSessionProvider).streamUrl, '');
    });
  });
}
