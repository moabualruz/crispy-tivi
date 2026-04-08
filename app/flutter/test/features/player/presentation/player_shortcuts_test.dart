import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/settings/domain/entities/remote_action.dart';

void main() {
  group('RemoteAction enum', () {
    test('has all 18 expected values', () {
      expect(RemoteAction.values.length, 18);
    });

    test('new actions have correct labels', () {
      expect(RemoteAction.openGuide.label, 'Open Guide');
      expect(RemoteAction.openSettings.label, 'Open Settings');
      expect(RemoteAction.startRecording.label, 'Start Recording');
      expect(RemoteAction.openSearch.label, 'Open Search');
      expect(RemoteAction.showDebug.label, 'Show Debug');
    });

    test('all values serialize and deserialize correctly', () {
      final original = defaultRemoteKeyMap;
      final json = serializeKeyMap(original);
      final restored = deserializeKeyMap(json);

      expect(restored.length, original.length);
      for (final entry in original.entries) {
        expect(
          restored[entry.key],
          entry.value,
          reason: 'Key ${entry.key} should map to ${entry.value}',
        );
      }
    });

    test('unknown action names are skipped on deserialize', () {
      final json = {'42': 'nonExistentAction', '43': 'playPause'};
      final result = deserializeKeyMap(json);
      expect(result.length, 1);
      expect(result[43], RemoteAction.playPause);
    });
  });

  group('defaultRemoteKeyMap', () {
    test('R key maps to startRecording', () {
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.keyR.keyId],
        RemoteAction.startRecording,
      );
    });

    test('G key maps to openGuide', () {
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.keyG.keyId],
        RemoteAction.openGuide,
      );
    });

    test('S key is reserved for screenshots, not openSettings', () {
      expect(defaultRemoteKeyMap[LogicalKeyboardKey.keyS.keyId], isNull);
    });

    test('D key maps to showDebug', () {
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.keyD.keyId],
        RemoteAction.showDebug,
      );
    });

    test('/ key maps to openSearch', () {
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.slash.keyId],
        RemoteAction.openSearch,
      );
    });

    test('existing mappings are preserved', () {
      expect(
        defaultRemoteKeyMap[LogicalKeyboardKey.space.keyId],
        RemoteAction.playPause,
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
        defaultRemoteKeyMap[LogicalKeyboardKey.arrowUp.keyId],
        RemoteAction.channelUp,
      );
    });
  });
}
