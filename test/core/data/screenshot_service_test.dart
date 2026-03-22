import 'dart:typed_data';

import 'package:crispy_tivi/core/data/app_directories.dart';
import 'package:crispy_tivi/core/data/screenshot_service.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';

// ── Fake CrispyPlayer ──────────────────────────────────────

/// Minimal [CrispyPlayer] stub that only implements
/// [screenshotRawBytes] — all other methods throw.
class _FakePlayer extends Fake implements CrispyPlayer {
  Uint8List? bytesToReturn;

  @override
  Future<Uint8List?> screenshotRawBytes() async => bytesToReturn;
}

void main() {
  late ScreenshotService service;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('screenshot_test_');
    AppDirectories.testRoot = tempDir.path;
    service = ScreenshotService();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ScreenshotService', () {
    test('captureLastFrame saves JPEG bytes to disk', () async {
      final player =
          _FakePlayer()
            ..bytesToReturn = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

      final path = await service.captureLastFrame(
        player: player,
        contentType: 'channel',
        contentId: 'abc123',
      );

      expect(path, isNotNull);
      final file = File(path!);
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), equals([0xFF, 0xD8, 0xFF, 0xE0]));
    });

    test('captureLastFrame returns null when player returns null', () async {
      final player = _FakePlayer()..bytesToReturn = null;

      final path = await service.captureLastFrame(
        player: player,
        contentType: 'movie',
        contentId: 'xyz789',
      );

      expect(path, isNull);
    });

    test('captureLastFrame returns null for empty bytes', () async {
      final player = _FakePlayer()..bytesToReturn = Uint8List(0);

      final path = await service.captureLastFrame(
        player: player,
        contentType: 'movie',
        contentId: 'empty',
      );

      expect(path, isNull);
    });

    test('getScreenshotPath returns path when file exists', () async {
      final player =
          _FakePlayer()..bytesToReturn = Uint8List.fromList([1, 2, 3]);

      await service.captureLastFrame(
        player: player,
        contentType: 'channel',
        contentId: 'ch1',
      );

      final path = service.getScreenshotPath('channel', 'ch1');
      expect(path, isNotNull);
      expect(File(path!).existsSync(), isTrue);
    });

    test('getScreenshotPath returns null when no file exists', () {
      final path = service.getScreenshotPath('channel', 'nonexistent');
      expect(path, isNull);
    });

    test('deleteScreenshot removes the file', () async {
      final player =
          _FakePlayer()..bytesToReturn = Uint8List.fromList([1, 2, 3]);

      final savedPath = await service.captureLastFrame(
        player: player,
        contentType: 'episode',
        contentId: 'ep42',
      );
      expect(File(savedPath!).existsSync(), isTrue);

      await service.deleteScreenshot('episode', 'ep42');
      expect(File(savedPath).existsSync(), isFalse);
    });

    test('deleteScreenshot is safe when file does not exist', () async {
      // Should not throw.
      await service.deleteScreenshot('movie', 'nofile');
    });

    test('clearAll removes all screenshots', () async {
      final player = _FakePlayer()..bytesToReturn = Uint8List.fromList([1]);

      await service.captureLastFrame(
        player: player,
        contentType: 'channel',
        contentId: 'a',
      );
      await service.captureLastFrame(
        player: player,
        contentType: 'movie',
        contentId: 'b',
      );

      await service.clearAll();

      expect(service.getScreenshotPath('channel', 'a'), isNull);
      expect(service.getScreenshotPath('movie', 'b'), isNull);
    });

    test('captureLastFrame overwrites existing screenshot', () async {
      final player = _FakePlayer();

      player.bytesToReturn = Uint8List.fromList([1, 1, 1]);
      await service.captureLastFrame(
        player: player,
        contentType: 'channel',
        contentId: 'ch1',
      );

      player.bytesToReturn = Uint8List.fromList([2, 2, 2]);
      await service.captureLastFrame(
        player: player,
        contentType: 'channel',
        contentId: 'ch1',
      );

      final path = service.getScreenshotPath('channel', 'ch1');
      expect(File(path!).readAsBytesSync(), equals([2, 2, 2]));
    });

    test('cleanupIfServerPosterExists deletes when URL provided', () async {
      final player = _FakePlayer()..bytesToReturn = Uint8List.fromList([1]);

      await service.captureLastFrame(
        player: player,
        contentType: 'movie',
        contentId: 'mov1',
      );
      expect(service.getScreenshotPath('movie', 'mov1'), isNotNull);

      await service.cleanupIfServerPosterExists(
        'movie',
        'mov1',
        'https://server.com/poster.jpg',
      );
      expect(service.getScreenshotPath('movie', 'mov1'), isNull);
    });

    test('cleanupIfServerPosterExists keeps when URL is null', () async {
      final player = _FakePlayer()..bytesToReturn = Uint8List.fromList([1]);

      await service.captureLastFrame(
        player: player,
        contentType: 'episode',
        contentId: 'ep1',
      );

      await service.cleanupIfServerPosterExists('episode', 'ep1', null);
      expect(service.getScreenshotPath('episode', 'ep1'), isNotNull);
    });

    test('cleanupIfServerPosterExists keeps when URL is empty', () async {
      final player = _FakePlayer()..bytesToReturn = Uint8List.fromList([1]);

      await service.captureLastFrame(
        player: player,
        contentType: 'episode',
        contentId: 'ep2',
      );

      await service.cleanupIfServerPosterExists('episode', 'ep2', '');
      expect(service.getScreenshotPath('episode', 'ep2'), isNotNull);
    });

    test('file path sanitizes content type and ID', () async {
      final player = _FakePlayer()..bytesToReturn = Uint8List.fromList([1]);

      final path = await service.captureLastFrame(
        player: player,
        contentType: '../evil',
        contentId: 'foo/bar',
      );

      expect(path, isNotNull);
      // Path should not contain traversal characters.
      expect(path!.contains('..'), isFalse);
      expect(path.contains('evil'), isTrue);
    });

    test('provider returns a ScreenshotService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final svc = container.read(screenshotServiceProvider);
      expect(svc, isA<ScreenshotService>());
    });
  });
}
