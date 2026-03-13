import 'package:crispy_tivi/features/player/domain/video_surface_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late VideoSurfaceManager manager;

  setUp(() {
    manager = VideoSurfaceManager();
  });

  group('VideoSurfaceManager — activateSurface', () {
    test('succeeds when no active surface', () {
      manager.activateSurface('surface-1');
      expect(manager.hasActiveSurface, isTrue);
      expect(manager.activeSurfaceId, 'surface-1');
    });

    test('succeeds when re-activating the same surface', () {
      manager.activateSurface('surface-1');
      manager.activateSurface('surface-1');
      expect(manager.activeSurfaceId, 'surface-1');
    });

    test('throws StateError when another surface is active', () {
      manager.activateSurface('surface-1');
      expect(() => manager.activateSurface('surface-2'), throwsStateError);
    });
  });

  group('VideoSurfaceManager — deactivateSurface', () {
    test('clears active surface', () {
      manager.activateSurface('surface-1');
      manager.deactivateSurface('surface-1');
      expect(manager.hasActiveSurface, isFalse);
      expect(manager.activeSurfaceId, isNull);
    });

    test('no-op when deactivating non-active surface', () {
      manager.activateSurface('surface-1');
      manager.deactivateSurface('surface-2');
      expect(manager.hasActiveSurface, isTrue);
      expect(manager.activeSurfaceId, 'surface-1');
    });

    test('allows new surface after deactivation', () {
      manager.activateSurface('surface-1');
      manager.deactivateSurface('surface-1');
      manager.activateSurface('surface-2');
      expect(manager.activeSurfaceId, 'surface-2');
    });
  });

  group('VideoSurfaceManager — reset', () {
    test('clears all active surfaces', () {
      manager.activateSurface('surface-1');
      manager.reset();
      expect(manager.hasActiveSurface, isFalse);
      expect(manager.activeSurfaceId, isNull);
    });

    test('allows new activation after reset', () {
      manager.activateSurface('surface-1');
      manager.reset();
      manager.activateSurface('surface-2');
      expect(manager.activeSurfaceId, 'surface-2');
    });
  });

  group('VideoSurfaceManager — initial state', () {
    test('starts with no active surface', () {
      expect(manager.hasActiveSurface, isFalse);
      expect(manager.activeSurfaceId, isNull);
    });
  });
}
