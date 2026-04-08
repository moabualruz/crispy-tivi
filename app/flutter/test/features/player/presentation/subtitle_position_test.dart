import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/subtitle_position_manager.dart';

class MockCrispyPlayer extends Mock implements CrispyPlayer {}

void main() {
  late MockCrispyPlayer player;
  late SubtitlePositionManager manager;

  setUp(() {
    player = MockCrispyPlayer();
    manager = SubtitlePositionManager(player: player);
  });

  tearDown(() => manager.dispose());

  group('calculateShiftedPosition', () {
    test('shifts position up by bar height + padding percentage', () {
      // 1080p video, 80px bar + 16px padding = 96px
      // 96 / 1080 * 100 ≈ 8.89 → round to 9
      // 100 - 9 = 91
      final result = SubtitlePositionManager.calculateShiftedPosition(
        userPosition: 100,
        barHeightPx: 80,
        videoHeightPx: 1080,
      );
      expect(result, 91);
    });

    test('respects user offset below 100', () {
      // User has subs at 90, shift ≈ 9
      // 90 - 9 = 81
      final result = SubtitlePositionManager.calculateShiftedPosition(
        userPosition: 90,
        barHeightPx: 80,
        videoHeightPx: 1080,
      );
      expect(result, 81);
    });

    test('zoom scale reduces shift', () {
      // 2x zoom: effective height = 2160
      // 96 / 2160 * 100 ≈ 4.44 → round to 4
      // 100 - 4 = 96
      final result = SubtitlePositionManager.calculateShiftedPosition(
        userPosition: 100,
        barHeightPx: 80,
        videoHeightPx: 1080,
        zoomScale: 2.0,
      );
      expect(result, 96);
    });

    test('clamps to 0 on very small video', () {
      // Tiny video: 50px, shift would be (96/50)*100 = 192
      // max(0, 100 - 192) = 0
      final result = SubtitlePositionManager.calculateShiftedPosition(
        userPosition: 100,
        barHeightPx: 80,
        videoHeightPx: 50,
      );
      expect(result, 0);
    });

    test('returns user position when video height is 0', () {
      final result = SubtitlePositionManager.calculateShiftedPosition(
        userPosition: 85,
        barHeightPx: 80,
        videoHeightPx: 0,
      );
      expect(result, 85);
    });

    test('720p video produces correct shift', () {
      // 720p: 96 / 720 * 100 ≈ 13.33 → round to 13
      // 100 - 13 = 87
      final result = SubtitlePositionManager.calculateShiftedPosition(
        userPosition: 100,
        barHeightPx: 80,
        videoHeightPx: 720,
      );
      expect(result, 87);
    });
  });

  group('onOsdVisibilityChanged', () {
    test('shifts sub-pos when OSD becomes visible', () {
      fakeAsync((async) {
        manager.onOsdVisibilityChanged(
          visible: true,
          barHeightPx: 80,
          videoHeightPx: 1080,
        );
        // Advance past animation duration.
        async.elapse(const Duration(milliseconds: 250));

        // Final position should be 91.
        expect(manager.currentPos, 91);
        verify(
          () => player.setProperty('sub-pos', '91'),
        ).called(greaterThan(0));
      });
    });

    test('restores sub-pos when OSD hides', () {
      fakeAsync((async) {
        // First shift up.
        manager.onOsdVisibilityChanged(
          visible: true,
          barHeightPx: 80,
          videoHeightPx: 1080,
        );
        async.elapse(const Duration(milliseconds: 250));
        clearInteractions(player);

        // Then restore.
        manager.onOsdVisibilityChanged(
          visible: false,
          barHeightPx: 80,
          videoHeightPx: 1080,
        );
        async.elapse(const Duration(milliseconds: 250));

        expect(manager.currentPos, 100);
        verify(
          () => player.setProperty('sub-pos', '100'),
        ).called(greaterThan(0));
      });
    });

    test('uses user offset when restoring', () {
      fakeAsync((async) {
        manager.updateUserPosition(85);

        manager.onOsdVisibilityChanged(
          visible: true,
          barHeightPx: 80,
          videoHeightPx: 1080,
        );
        async.elapse(const Duration(milliseconds: 250));
        clearInteractions(player);

        manager.onOsdVisibilityChanged(
          visible: false,
          barHeightPx: 80,
          videoHeightPx: 1080,
        );
        async.elapse(const Duration(milliseconds: 250));

        // Should restore to user's 85, not default 100.
        expect(manager.currentPos, 85);
        verify(
          () => player.setProperty('sub-pos', '85'),
        ).called(greaterThan(0));
      });
    });

    test('does nothing when video height is 0', () {
      manager.onOsdVisibilityChanged(
        visible: true,
        barHeightPx: 80,
        videoHeightPx: 0,
      );

      verifyNever(() => player.setProperty(any(), any()));
    });

    test('accounts for zoom when shifting', () {
      fakeAsync((async) {
        manager.onOsdVisibilityChanged(
          visible: true,
          barHeightPx: 80,
          videoHeightPx: 1080,
          zoomScale: 2.0,
        );
        async.elapse(const Duration(milliseconds: 250));

        // 96 / 2160 * 100 ≈ 4 → 100 - 4 = 96
        expect(manager.currentPos, 96);
        verify(
          () => player.setProperty('sub-pos', '96'),
        ).called(greaterThan(0));
      });
    });
  });

  group('updateUserPosition', () {
    test('updates base position', () {
      fakeAsync((async) {
        manager.updateUserPosition(90);

        // Show and hide to verify the new base is used.
        manager.onOsdVisibilityChanged(
          visible: true,
          barHeightPx: 80,
          videoHeightPx: 1080,
        );
        async.elapse(const Duration(milliseconds: 250));
        clearInteractions(player);

        manager.onOsdVisibilityChanged(
          visible: false,
          barHeightPx: 80,
          videoHeightPx: 1080,
        );
        async.elapse(const Duration(milliseconds: 250));

        expect(manager.currentPos, 90);
        verify(
          () => player.setProperty('sub-pos', '90'),
        ).called(greaterThan(0));
      });
    });
  });

  group('dispose', () {
    test('cancels animation timer', () {
      fakeAsync((async) {
        // Trigger an animation.
        manager.onOsdVisibilityChanged(
          visible: true,
          barHeightPx: 80,
          videoHeightPx: 1080,
        );

        // Dispose mid-animation — should not throw.
        manager.dispose();

        // Advancing time should not cause setProperty calls
        // after dispose.
        clearInteractions(player);
        async.elapse(const Duration(milliseconds: 250));
        verifyNever(() => player.setProperty(any(), any()));
      });
    });
  });
}
