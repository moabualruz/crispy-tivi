import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/settings/domain/entities/remote_action.dart';

void main() {
  // ── RemoteAction enum ────────────────────────────

  group('RemoteAction', () {
    test('has all expected values', () {
      expect(
        RemoteAction.values,
        containsAll([
          RemoteAction.playPause,
          RemoteAction.channelUp,
          RemoteAction.channelDown,
          RemoteAction.volumeUp,
          RemoteAction.volumeDown,
          RemoteAction.seekForward,
          RemoteAction.seekBack,
          RemoteAction.mute,
          RemoteAction.fullscreen,
          RemoteAction.back,
          RemoteAction.toggleZap,
          RemoteAction.showOsd,
          RemoteAction.toggleCaptions,
          RemoteAction.openGuide,
          RemoteAction.openSettings,
          RemoteAction.startRecording,
          RemoteAction.openSearch,
          RemoteAction.showDebug,
        ]),
      );
      expect(RemoteAction.values, hasLength(18));
    });

    test('each action has a non-empty label', () {
      for (final action in RemoteAction.values) {
        expect(
          action.label,
          isNotEmpty,
          reason: '${action.name} should have label',
        );
      }
    });

    test('labels are human-readable strings', () {
      expect(RemoteAction.playPause.label, 'Play / Pause');
      expect(RemoteAction.channelUp.label, 'Channel Up');
      expect(RemoteAction.seekForward.label, 'Seek Forward');
      expect(RemoteAction.showOsd.label, 'Show Controls');
    });
  });

  // ── defaultRemoteKeyMap ──────────────────────────

  group('defaultRemoteKeyMap', () {
    test('contains keyboard keys', () {
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.space.keyId],
        RemoteAction.playPause,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.arrowUp.keyId],
        RemoteAction.channelUp,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.arrowDown.keyId],
        RemoteAction.channelDown,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.arrowLeft.keyId],
        RemoteAction.seekBack,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.arrowRight.keyId],
        RemoteAction.seekForward,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.keyM.keyId],
        RemoteAction.mute,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.keyF.keyId],
        RemoteAction.fullscreen,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.escape.keyId],
        RemoteAction.back,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.browserBack.keyId],
        RemoteAction.back,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.channelUp.keyId],
        RemoteAction.channelUp,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.channelDown.keyId],
        RemoteAction.channelDown,
      );
    });

    test('contains gamepad buttons', () {
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.gameButtonA.keyId],
        RemoteAction.playPause,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.gameButtonB.keyId],
        RemoteAction.back,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.gameButtonX.keyId],
        RemoteAction.toggleZap,
      );
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.gameButtonY.keyId],
        RemoteAction.showOsd,
      );
    });

    test('has no duplicate key IDs', () {
      final keys = defaultRemoteKeyMap.keys.toList();
      expect(
        keys.toSet().length,
        keys.length,
        reason: 'key map should have unique key IDs',
      );
    });

    test('does not shadow direct screenshot or lock shortcuts', () {
      expect(
        defaultRemoteKeyMap.containsKey(LogicalKeyboardKey.keyS.keyId),
        isFalse,
      );
      expect(
        defaultRemoteKeyMap.containsKey(LogicalKeyboardKey.keyL.keyId),
        isFalse,
      );
    });
  });

  // ── serializeKeyMap ──────────────────────────────

  group('serializeKeyMap', () {
    test('converts int keys to string keys', () {
      final map = {42: RemoteAction.playPause, 99: RemoteAction.mute};
      final result = serializeKeyMap(map);

      expect(result['42'], 'playPause');
      expect(result['99'], 'mute');
      expect(result.length, 2);
    });

    test('empty map returns empty map', () {
      final result = serializeKeyMap({});
      expect(result, isEmpty);
    });

    test('round-trips with deserializeKeyMap', () {
      final original = {
        LogicalKeyboardKey.space.keyId: RemoteAction.playPause,
        LogicalKeyboardKey.keyM.keyId: RemoteAction.mute,
        LogicalKeyboardKey.keyF.keyId: RemoteAction.fullscreen,
      };
      final serialized = serializeKeyMap(original);
      final restored = deserializeKeyMap(serialized);

      expect(restored, equals(original));
    });
  });

  // ── deserializeKeyMap ────────────────────────────

  group('deserializeKeyMap', () {
    test('converts string keys back to int keys', () {
      final json = {'42': 'playPause', '99': 'mute'};
      final result = deserializeKeyMap(json);

      expect(result[42], RemoteAction.playPause);
      expect(result[99], RemoteAction.mute);
    });

    test('skips invalid key IDs', () {
      final json = {'not_a_number': 'playPause', '42': 'mute'};
      final result = deserializeKeyMap(json);

      expect(result.length, 1);
      expect(result[42], RemoteAction.mute);
    });

    test('skips unknown action names', () {
      final json = {'42': 'playPause', '99': 'nonExistentAction'};
      final result = deserializeKeyMap(json);

      expect(result.length, 1);
      expect(result[42], RemoteAction.playPause);
    });

    test('empty JSON returns empty map', () {
      final result = deserializeKeyMap({});
      expect(result, isEmpty);
    });

    test('full default map round-trips correctly', () {
      final serialized = serializeKeyMap(defaultRemoteKeyMap);
      final restored = deserializeKeyMap(serialized);

      expect(restored.length, defaultRemoteKeyMap.length);
      for (final entry in defaultRemoteKeyMap.entries) {
        expect(
          restored[entry.key],
          entry.value,
          reason:
              'Key ${entry.key} should map '
              'to ${entry.value.name}',
        );
      }
    });
  });

  // ── keyLabel ─────────────────────────────────────

  group('keyLabel', () {
    test('returns readable label for known key', () {
      final label = keyLabel(LogicalKeyboardKey.space.keyId);
      expect(label, isNotEmpty);
      // Space key label varies by platform, but
      // should not be the raw "Key <id>" fallback.
      expect(
        label.startsWith('Key '),
        isFalse,
        reason: 'Space should have a real label',
      );
    });

    test('returns fallback for unknown key ID', () {
      // Use a nonsensical key ID.
      final label = keyLabel(0xDEADBEEF);
      expect(label, contains('Key'));
    });
  });
}
