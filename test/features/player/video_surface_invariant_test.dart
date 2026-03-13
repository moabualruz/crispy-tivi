import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/video_surface_manager.dart';

void main() {
  late VideoSurfaceManager manager;

  setUp(() {
    manager = VideoSurfaceManager();
  });

  group('VideoSurfaceManager invariants', () {
    test('starts with no active surface', () {
      expect(manager.hasActiveSurface, isFalse);
      expect(manager.activeSurfaceId, isNull);
    });

    test('activating a surface makes it active', () {
      manager.activateSurface('surface-1');
      expect(manager.hasActiveSurface, isTrue);
      expect(manager.activeSurfaceId, 'surface-1');
    });

    test('activating same surface twice is idempotent', () {
      manager.activateSurface('surface-1');
      manager.activateSurface('surface-1');
      expect(manager.hasActiveSurface, isTrue);
      expect(manager.activeSurfaceId, 'surface-1');
    });

    test(
      'activating different surface while one is active throws StateError',
      () {
        manager.activateSurface('surface-1');
        expect(() => manager.activateSurface('surface-2'), throwsStateError);
        // Original surface remains active after failed activation.
        expect(manager.activeSurfaceId, 'surface-1');
      },
    );

    test('deactivate then reactivate works cleanly', () {
      manager.activateSurface('surface-1');
      manager.deactivateSurface('surface-1');
      expect(manager.hasActiveSurface, isFalse);

      manager.activateSurface('surface-2');
      expect(manager.activeSurfaceId, 'surface-2');
    });

    test('deactivating non-active surface is no-op', () {
      manager.activateSurface('surface-1');
      manager.deactivateSurface('surface-other');
      expect(manager.activeSurfaceId, 'surface-1');
    });

    test('deactivating when no surface is active is no-op', () {
      manager.deactivateSurface('surface-1');
      expect(manager.hasActiveSurface, isFalse);
    });

    test('rapid activate/deactivate cycles leave manager in clean state', () {
      for (var i = 0; i < 10; i++) {
        final id = 'surface-$i';
        manager.activateSurface(id);
        expect(manager.activeSurfaceId, id);
        manager.deactivateSurface(id);
        expect(manager.hasActiveSurface, isFalse);
      }
      expect(manager.activeSurfaceId, isNull);
    });

    test('rapid same-surface activate/deactivate cycles', () {
      for (var i = 0; i < 10; i++) {
        manager.activateSurface('persistent');
        expect(manager.activeSurfaceId, 'persistent');
        manager.deactivateSurface('persistent');
        expect(manager.hasActiveSurface, isFalse);
      }
    });

    test('reset clears state when surface is active', () {
      manager.activateSurface('surface-1');
      manager.reset();
      expect(manager.hasActiveSurface, isFalse);
      expect(manager.activeSurfaceId, isNull);
    });

    test('reset clears state when no surface is active', () {
      manager.reset();
      expect(manager.hasActiveSurface, isFalse);
    });

    test('reset after failed activation clears original surface', () {
      manager.activateSurface('surface-1');
      expect(() => manager.activateSurface('surface-2'), throwsStateError);
      manager.reset();
      expect(manager.hasActiveSurface, isFalse);
      // Can now activate any surface.
      manager.activateSurface('surface-3');
      expect(manager.activeSurfaceId, 'surface-3');
    });

    test('after reset can activate new surface', () {
      manager.activateSurface('surface-1');
      manager.reset();
      manager.activateSurface('surface-2');
      expect(manager.activeSurfaceId, 'surface-2');
    });
  });
}
