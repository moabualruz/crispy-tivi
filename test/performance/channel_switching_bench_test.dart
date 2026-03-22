import 'dart:typed_data';

import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lightweight mock player for benchmarking channel switch latency.
///
/// Measures the time from [open] call to stream-ready state without
/// real media_kit overhead. This isolates provider + backend latency.
class _BenchPlayer implements CrispyPlayer {
  String? _currentUrl;
  bool _isPlaying = false;
  bool _disposed = false;

  @override
  Future<void> open(
    String url, {
    Map<String, String>? httpHeaders,
    Map<String, dynamic>? extras,
    Duration startPosition = Duration.zero,
  }) async {
    _currentUrl = url;
    _isPlaying = true;
  }

  @override
  Future<void> play() async => _isPlaying = true;
  @override
  Future<void> pause() async => _isPlaying = false;
  @override
  Future<void> playOrPause() async => _isPlaying ? await pause() : await play();
  @override
  Future<void> stop() async {
    _isPlaying = false;
    _currentUrl = null;
  }

  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> setAudioTrack(int index) async {}
  @override
  Future<void> setSubtitleTrack(int index) async {}
  @override
  void setSecondarySubtitleTrack(int index) {}

  @override
  Future<void> dispose() async => _disposed = true;

  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration> get durationStream => const Stream.empty();
  @override
  Stream<Duration> get bufferStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<bool> get completedStream => const Stream.empty();
  @override
  Stream<String?> get errorStream => const Stream.empty();
  @override
  Stream<bool> get bufferingStream => const Stream.empty();
  @override
  Stream<double> get volumeStream => const Stream.empty();
  @override
  Stream<double> get rateStream => const Stream.empty();
  @override
  Stream<CrispyTrackList> get tracksStream => const Stream.empty();

  @override
  Duration get position => Duration.zero;
  @override
  Duration get duration => const Duration(hours: 1);
  @override
  bool get isPlaying => _isPlaying;
  @override
  double get volume => 1.0;
  @override
  double get rate => 1.0;
  @override
  String? get currentUrl => _currentUrl;

  @override
  List<CrispyAudioTrack> get audioTracks => const [];
  @override
  List<CrispySubtitleTrack> get subtitleTracks => const [];

  @override
  Widget buildVideoWidget({BoxFit fit = BoxFit.contain}) =>
      const SizedBox.shrink();

  @override
  void setProperty(String key, String value) {}
  @override
  String? getProperty(String key) => null;

  @override
  bool get supportsHdr => false;
  @override
  bool get supportsPiP => false;
  @override
  bool get supportsBackgroundAudio => false;
  @override
  String get engineName => 'bench';

  @override
  Future<Uint8List?> screenshotRawBytes() async => null;

  @override
  List<CrispyAudioDevice> get audioDevices => const [];
  @override
  String? get currentAudioDeviceName => null;
  @override
  void setAudioDevice(String name) {}

  bool get isDisposed => _disposed;
}

void main() {
  group('PERF-01: Channel Switching Benchmark', () {
    late MemoryBackend backend;
    late CacheService cache;

    setUp(() {
      backend = MemoryBackend();
      cache = CacheService(backend);
    });

    test('channel switch completes in under 500ms', () async {
      // Seed a source and channels into MemoryBackend.
      await backend.saveSource({
        'id': 'src-1',
        'name': 'Test IPTV',
        'url': 'http://example.com/playlist.m3u',
        'source_type': 'xtream',
        'sort_order': 0,
        'enabled': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await backend.saveChannels([
        {
          'id': 'ch-1',
          'name': 'Channel 1',
          'stream_url': 'http://example.com/ch1.m3u8',
          'channel_group': 'News',
          'source_id': 'src-1',
          'sort_order': 0,
        },
        {
          'id': 'ch-2',
          'name': 'Channel 2',
          'stream_url': 'http://example.com/ch2.m3u8',
          'channel_group': 'Sports',
          'source_id': 'src-1',
          'sort_order': 1,
        },
        {
          'id': 'ch-3',
          'name': 'Channel 3',
          'stream_url': 'http://example.com/ch3.m3u8',
          'channel_group': 'News',
          'source_id': 'src-1',
          'sort_order': 2,
        },
      ]);

      final player = _BenchPlayer();

      // Initial channel open.
      await player.open('http://example.com/ch1.m3u8');
      expect(player.isPlaying, isTrue);

      // Measure switching from ch1 -> ch2.
      final stopwatch = Stopwatch()..start();

      // Stop current channel.
      await player.stop();

      // Load channel data from backend (simulates provider lookup).
      final channels = await backend.getChannelsBySources(['src-1']);
      final targetChannel = channels.firstWhere((c) => c['id'] == 'ch-2');

      // Open new channel.
      await player.open(targetChannel['stream_url'] as String);

      stopwatch.stop();

      // Verify switch completed and player is on the new channel.
      expect(player.isPlaying, isTrue);
      expect(player.currentUrl, 'http://example.com/ch2.m3u8');

      // PERF-01 assertion: channel switch must complete in under 500ms.
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason:
            'Channel switch took ${stopwatch.elapsedMilliseconds}ms, '
            'must be under 500ms',
      );
    });

    test(
      'rapid channel zapping (10 switches) stays under 500ms each',
      () async {
        // Seed channels.
        await backend.saveSource({
          'id': 'src-1',
          'name': 'Test IPTV',
          'url': 'http://example.com/playlist.m3u',
          'source_type': 'xtream',
          'sort_order': 0,
          'enabled': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        final channelData = List.generate(
          10,
          (i) => {
            'id': 'ch-$i',
            'name': 'Channel $i',
            'stream_url': 'http://example.com/ch$i.m3u8',
            'channel_group': 'Group ${i % 3}',
            'source_id': 'src-1',
            'sort_order': i,
          },
        );
        await backend.saveChannels(channelData);

        final player = _BenchPlayer();
        await player.open(channelData.first['stream_url'] as String);

        // Rapidly switch through all 10 channels, measuring each.
        for (var i = 1; i < channelData.length; i++) {
          final stopwatch = Stopwatch()..start();

          await player.stop();
          final channels = await backend.getChannelsBySources(['src-1']);
          final target = channels.firstWhere((c) => c['id'] == 'ch-$i');
          await player.open(target['stream_url'] as String);

          stopwatch.stop();

          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(500),
            reason:
                'Switch to channel $i took '
                '${stopwatch.elapsedMilliseconds}ms, must be under 500ms',
          );
        }

        await player.dispose();
        expect(player.isDisposed, isTrue);
      },
    );

    test('channel switch with CacheService layer stays under 500ms', () async {
      // Verify CacheService wrapper does not add significant overhead.
      await backend.saveSource({
        'id': 'src-1',
        'name': 'Test IPTV',
        'url': 'http://example.com/playlist.m3u',
        'source_type': 'xtream',
        'sort_order': 0,
        'enabled': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await backend.saveChannels([
        {
          'id': 'ch-a',
          'name': 'Channel A',
          'stream_url': 'http://example.com/chA.m3u8',
          'channel_group': 'Movies',
          'source_id': 'src-1',
          'sort_order': 0,
        },
        {
          'id': 'ch-b',
          'name': 'Channel B',
          'stream_url': 'http://example.com/chB.m3u8',
          'channel_group': 'Movies',
          'source_id': 'src-1',
          'sort_order': 1,
        },
      ]);

      final player = _BenchPlayer();
      await player.open('http://example.com/chA.m3u8');

      final stopwatch = Stopwatch()..start();

      await player.stop();

      // Use CacheService to load channels (closer to production path).
      final domainChannels = await cache.getChannelsBySources(['src-1']);
      final target = domainChannels.firstWhere((c) => c.name == 'Channel B');
      await player.open(target.streamUrl);

      stopwatch.stop();

      expect(player.currentUrl, 'http://example.com/chB.m3u8');
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason:
            'CacheService channel switch took '
            '${stopwatch.elapsedMilliseconds}ms, must be under 500ms',
      );

      await player.dispose();
    });
  });
}
