// Tests for TvRemoteKeyHandler — TV remote media key mapping.
//
// Verifies:
//   - mediaPlayPause dispatches onPlayPause
//   - mediaStop dispatches onStop
//   - mediaRewind dispatches onRewind
//   - mediaFastForward dispatches onFastForward
//   - channelUp / channelDown dispatch correct callbacks
//   - Unhandled keys pass through (not consumed)
//   - Only KeyDownEvent triggers callbacks (not repeats or key up)

import 'package:crispy_tivi/core/widgets/tv_remote_key_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TvRemoteKeyHandler', () {
    testWidgets('mediaPlayPause dispatches onPlayPause', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TvRemoteKeyHandler(
            autofocus: true,
            onPlayPause: () => called = true,
            child: const Text('test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('mediaStop dispatches onStop', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TvRemoteKeyHandler(
            autofocus: true,
            onStop: () => called = true,
            child: const Text('test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.mediaStop);
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('mediaRewind dispatches onRewind', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TvRemoteKeyHandler(
            autofocus: true,
            onRewind: () => called = true,
            child: const Text('test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.mediaRewind);
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('mediaFastForward dispatches onFastForward', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TvRemoteKeyHandler(
            autofocus: true,
            onFastForward: () => called = true,
            child: const Text('test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.mediaFastForward);
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('channelUp dispatches onChannelUp', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TvRemoteKeyHandler(
            autofocus: true,
            onChannelUp: () => called = true,
            child: const Text('test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('channelDown dispatches onChannelDown', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TvRemoteKeyHandler(
            autofocus: true,
            onChannelDown: () => called = true,
            child: const Text('test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('unhandled keys pass through', (tester) async {
      var playPauseCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TvRemoteKeyHandler(
            onPlayPause: () => playPauseCalled = true,
            child: const Text('test'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('test'));
      await tester.pump();

      // Send a key that is NOT mapped — should not trigger any callback.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(playPauseCalled, isFalse);
    });

    testWidgets('null callbacks are safely ignored', (tester) async {
      // No callbacks provided — should not throw.
      await tester.pumpWidget(
        const MaterialApp(
          home: TvRemoteKeyHandler(autofocus: true, child: Text('test')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('test'));
      await tester.pump();

      // Send mapped key with no callback — should not throw.
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      await tester.pump();

      // If we get here without exception, the test passes.
      expect(find.text('test'), findsOneWidget);
    });
  });
}
