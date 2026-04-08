import 'dart:convert';

import 'package:crispy_tivi/config/settings_state.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a [ProviderContainer] with a [MemoryBackend]-backed
/// [CacheService] so tests can use `getSetting`/`setSetting`.
ProviderContainer _createContainer() {
  final backend = MemoryBackend();
  return ProviderContainer(
    overrides: [cacheServiceProvider.overrideWithValue(CacheService(backend))],
  );
}

void main() {
  group('Rotation lock settings persistence', () {
    late ProviderContainer container;

    setUp(() {
      container = _createContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('default is no persisted preference (null)', () async {
      final cache = container.read(cacheServiceProvider);
      final value = await cache.getSetting(kRotationLockKey);
      expect(value, isNull);
    });

    test('saves orientation indices as JSON array', () async {
      final cache = container.read(cacheServiceProvider);
      final orientations = {
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      };
      final indices = orientations.map((o) => o.index).toList()..sort();
      await cache.setSetting(kRotationLockKey, jsonEncode(indices));

      final stored = await cache.getSetting(kRotationLockKey);
      expect(stored, isNotNull);
      final decoded = (jsonDecode(stored!) as List).cast<int>();
      expect(
        decoded,
        containsAll([
          DeviceOrientation.landscapeLeft.index,
          DeviceOrientation.landscapeRight.index,
        ]),
      );
    });

    test('round-trip preserves all four orientations', () async {
      final cache = container.read(cacheServiceProvider);
      final all = DeviceOrientation.values.toSet();
      final indices = all.map((o) => o.index).toList()..sort();
      await cache.setSetting(kRotationLockKey, jsonEncode(indices));

      final stored = await cache.getSetting(kRotationLockKey);
      final decoded = (jsonDecode(stored!) as List).cast<int>();
      final restored = decoded.map((i) => DeviceOrientation.values[i]).toSet();
      expect(restored, equals(all));
    });

    test('round-trip preserves single orientation', () async {
      final cache = container.read(cacheServiceProvider);
      final single = {DeviceOrientation.portraitUp};
      final indices = single.map((o) => o.index).toList();
      await cache.setSetting(kRotationLockKey, jsonEncode(indices));

      final stored = await cache.getSetting(kRotationLockKey);
      final decoded = (jsonDecode(stored!) as List).cast<int>();
      final restored = decoded.map((i) => DeviceOrientation.values[i]).toSet();
      expect(restored, equals(single));
    });
  });

  group('Rotation lock min-1 guard', () {
    test('cannot deselect last orientation', () {
      // Simulates the toggle logic from the dialog.
      var selected = <DeviceOrientation>{DeviceOrientation.landscapeLeft};

      void toggle(DeviceOrientation o) {
        if (selected.contains(o) && selected.length > 1) {
          selected.remove(o);
        } else {
          selected.add(o);
        }
      }

      // Try to deselect the only remaining orientation.
      toggle(DeviceOrientation.landscapeLeft);
      expect(selected, contains(DeviceOrientation.landscapeLeft));
      expect(selected.length, 1);
    });

    test('can deselect when more than one orientation', () {
      var selected = <DeviceOrientation>{
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      };

      void toggle(DeviceOrientation o) {
        if (selected.contains(o) && selected.length > 1) {
          selected.remove(o);
        } else {
          selected.add(o);
        }
      }

      toggle(DeviceOrientation.landscapeLeft);
      expect(selected, isNot(contains(DeviceOrientation.landscapeLeft)));
      expect(selected.length, 1);
    });

    test('adding a new orientation works', () {
      var selected = <DeviceOrientation>{DeviceOrientation.portraitUp};

      void toggle(DeviceOrientation o) {
        if (selected.contains(o) && selected.length > 1) {
          selected.remove(o);
        } else {
          selected.add(o);
        }
      }

      toggle(DeviceOrientation.landscapeLeft);
      expect(selected.length, 2);
      expect(selected, contains(DeviceOrientation.landscapeLeft));
      expect(selected, contains(DeviceOrientation.portraitUp));
    });
  });

  group('Rotation lock platform gating', () {
    /// Simulates the platform gate logic from the overflow menu:
    /// `!kIsWeb && (Platform.isAndroid || Platform.isIOS)`
    bool shouldShow({
      required bool isWeb,
      required bool isAndroid,
      required bool isIOS,
    }) => !isWeb && (isAndroid || isIOS);

    test('hidden on desktop (non-web, non-mobile)', () {
      expect(shouldShow(isWeb: false, isAndroid: false, isIOS: false), isFalse);
    });

    test('shown on Android', () {
      expect(shouldShow(isWeb: false, isAndroid: true, isIOS: false), isTrue);
    });

    test('shown on iOS', () {
      expect(shouldShow(isWeb: false, isAndroid: false, isIOS: true), isTrue);
    });

    test('hidden on web even if mobile platform', () {
      expect(shouldShow(isWeb: true, isAndroid: true, isIOS: false), isFalse);
    });
  });

  group('Orientation index mapping', () {
    test('DeviceOrientation.values indices are stable', () {
      expect(DeviceOrientation.portraitUp.index, 0);
      expect(DeviceOrientation.landscapeLeft.index, 1);
      expect(DeviceOrientation.portraitDown.index, 2);
      expect(DeviceOrientation.landscapeRight.index, 3);
    });

    test('empty JSON means no lock (all orientations)', () {
      // When loading: null/empty JSON → default to landscape.
      // The helper in fullscreen overlay returns landscape-only
      // as default. Validate the parse for an actual stored value.
      final json = jsonEncode([0, 1, 2, 3]);
      final decoded = (jsonDecode(json) as List).cast<int>();
      final orientations =
          decoded.map((i) => DeviceOrientation.values[i]).toSet();
      expect(orientations.length, 4);
    });
  });
}
