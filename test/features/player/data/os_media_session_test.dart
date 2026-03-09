import 'package:crispy_tivi/features/player/data/os_media_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaAction', () {
    test('enum has all expected values', () {
      expect(MediaAction.values, hasLength(5));
      expect(
        MediaAction.values,
        containsAll([
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.next,
          MediaAction.previous,
        ]),
      );
    });
  });

  group('OsMediaSession', () {
    test('can be constructed without errors', () {
      final session = OsMediaSession();
      expect(session, isNotNull);
    });

    test('actions stream is broadcast', () {
      final session = OsMediaSession();
      // Should allow multiple listeners without error.
      final sub1 = session.actions.listen((_) {});
      final sub2 = session.actions.listen((_) {});
      sub1.cancel();
      sub2.cancel();
    });

    test('activate does not throw on test platform', () async {
      // In test environment, audio_service/smtc_windows
      // native code is unavailable. activate() should
      // handle the init failure gracefully (debugPrint).
      final session = OsMediaSession();
      await expectLater(session.activate(title: 'Test Channel'), completes);
    });

    test('updatePlaybackState does not throw when uninitialized', () async {
      final session = OsMediaSession();
      await expectLater(
        session.updatePlaybackState(true, Duration.zero),
        completes,
      );
    });

    test('deactivate does not throw when uninitialized', () async {
      final session = OsMediaSession();
      await expectLater(session.deactivate(), completes);
    });

    test('dispose completes without errors', () async {
      final session = OsMediaSession();
      await expectLater(session.dispose(), completes);
    });

    test('activate with all metadata parameters completes', () async {
      final session = OsMediaSession();
      await expectLater(
        session.activate(
          title: 'Movie Title',
          artist: 'Source Name',
          artUrl: 'https://example.com/poster.jpg',
          duration: const Duration(hours: 1, minutes: 30),
        ),
        completes,
      );
    });

    test('multiple activate calls complete', () async {
      final session = OsMediaSession();
      await session.activate(title: 'Channel 1');
      await session.activate(title: 'Channel 2');
      await session.activate(title: 'Channel 3');
      // No errors — graceful degradation in test env.
    });
  });
}
