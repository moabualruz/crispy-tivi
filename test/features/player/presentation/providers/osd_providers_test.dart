import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/presentation/providers/osd_providers.dart';
import 'package:crispy_tivi/core/theme/crispy_animation.dart';

void main() {
  group('OsdStateNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is visible', () {
      expect(container.read(osdStateProvider), equals(OsdState.visible));
    });

    test('show resets hide timer', () {
      fakeAsync((async) {
        final notifier = container.read(osdStateProvider.notifier);

        notifier.show();
        expect(container.read(osdStateProvider), equals(OsdState.visible));

        // Advance past hide timeout to ensure fading starts
        async.elapse(
          CrispyAnimation.osdAutoHide + const Duration(milliseconds: 10),
        );
        expect(container.read(osdStateProvider), equals(OsdState.fading));

        // Advance past fade timeout
        async.elapse(
          CrispyAnimation.osdHide + const Duration(milliseconds: 10),
        );
        expect(container.read(osdStateProvider), equals(OsdState.hidden));
      });
    });

    test('onPlaybackStateChanged paused pins OSD', () {
      fakeAsync((async) {
        final notifier = container.read(osdStateProvider.notifier);

        notifier.show();
        notifier.onPlaybackStateChanged(false); // Paused

        // Wait indefinite amount of time
        async.elapse(const Duration(minutes: 5));

        // OSD should still be visible because timers were cancelled
        expect(container.read(osdStateProvider), equals(OsdState.visible));
      });
    });

    test('freezeTimer halts timeout', () {
      fakeAsync((async) {
        final notifier = container.read(osdStateProvider.notifier);

        notifier.show();
        async.elapse(const Duration(seconds: 1)); // Elapse part of the time
        notifier.freezeTimer();

        async.elapse(
          const Duration(minutes: 5),
        ); // Elapse large duration while frozen
        expect(container.read(osdStateProvider), equals(OsdState.visible));
      });
    });
  });

  group('PlayerLockedNotifier', () {
    test('toggles lock state', () {
      final container = ProviderContainer();
      final notifier = container.read(playerLockedProvider.notifier);

      expect(container.read(playerLockedProvider), isFalse);

      notifier.toggle();
      expect(container.read(playerLockedProvider), isTrue);

      notifier.setLocked(value: false);
      expect(container.read(playerLockedProvider), isFalse);
    });
  });

  group('VideoZoomNotifier', () {
    test('updates and resets scale', () {
      final container = ProviderContainer();
      final notifier = container.read(videoZoomScaleProvider.notifier);

      expect(container.read(videoZoomScaleProvider), equals(1.0));

      notifier.setScale(2.5);
      expect(container.read(videoZoomScaleProvider), equals(2.5));

      notifier.reset();
      expect(container.read(videoZoomScaleProvider), equals(1.0));
    });
  });
}
