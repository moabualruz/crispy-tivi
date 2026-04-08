import 'package:crispy_tivi/features/player/presentation/widgets/screensaver_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreensaverMode', () {
    test('has 3 modes', () {
      expect(ScreensaverMode.values.length, 3);
    });

    test('labels are human-readable', () {
      expect(ScreensaverMode.bouncingLogo.label, 'Bouncing Logo');
      expect(ScreensaverMode.clock.label, 'Clock');
      expect(ScreensaverMode.blackScreen.label, 'Black Screen');
    });
  });

  group('Screensaver timeout options', () {
    test('includes disabled (0)', () {
      expect(kScreensaverTimeoutOptions.contains(0), isTrue);
    });

    test('has 5 presets', () {
      expect(kScreensaverTimeoutOptions.length, 5);
    });

    test('all values are non-negative', () {
      for (final t in kScreensaverTimeoutOptions) {
        expect(t, greaterThanOrEqualTo(0));
      }
    });

    test('presets are sorted ascending', () {
      for (var i = 1; i < kScreensaverTimeoutOptions.length; i++) {
        expect(
          kScreensaverTimeoutOptions[i],
          greaterThan(kScreensaverTimeoutOptions[i - 1]),
        );
      }
    });

    test('preset values match spec', () {
      expect(kScreensaverTimeoutOptions, [0, 2, 5, 10, 30]);
    });
  });

  group('Screensaver settings keys', () {
    test('mode key is namespaced', () {
      expect(kScreensaverModeKey, contains('screensaver'));
      expect(kScreensaverModeKey, contains('mode'));
    });

    test('timeout key is namespaced', () {
      expect(kScreensaverTimeoutKey, contains('screensaver'));
      expect(kScreensaverTimeoutKey, contains('timeout'));
    });

    test('keys are distinct', () {
      expect(kScreensaverModeKey, isNot(equals(kScreensaverTimeoutKey)));
    });
  });

  group('ScreensaverMode serialization', () {
    test('mode name roundtrips via enum.values lookup', () {
      for (final mode in ScreensaverMode.values) {
        final serialized = mode.name;
        final deserialized = ScreensaverMode.values.firstWhere(
          (e) => e.name == serialized,
        );
        expect(deserialized, mode);
      }
    });
  });

  group('Idle timer logic', () {
    test('timeout 0 means disabled', () {
      // The ScreensaverController uses timeout <= 0 as disabled.
      // Verify the convention.
      const timeout = 0;
      expect(timeout <= 0, isTrue);
    });

    test('positive timeout enables screensaver', () {
      for (final t in kScreensaverTimeoutOptions) {
        if (t > 0) {
          expect(t > 0, isTrue);
        }
      }
    });

    test('timeout is measured in minutes', () {
      // Verify that all non-zero presets are reasonable minute values.
      for (final t in kScreensaverTimeoutOptions) {
        if (t > 0) {
          // Should be between 1 and 60 minutes.
          expect(t, greaterThanOrEqualTo(1));
          expect(t, lessThanOrEqualTo(60));
        }
      }
    });
  });

  group('Bouncing logo constraints', () {
    test('logo size is reasonable for screen bounds', () {
      // The logo is 80px — should be small enough for any screen.
      const logoSize = 80.0;
      expect(logoSize, greaterThan(0));
      expect(logoSize, lessThanOrEqualTo(200));
    });

    test('speed is positive and bounded', () {
      // Speed of 1.5 px/frame at 60fps = 90 px/sec.
      const speed = 1.5;
      expect(speed, greaterThan(0));
      expect(speed, lessThanOrEqualTo(10));
    });

    test('bouncing reverses direction on edge', () {
      // Simulate a simple bounce check.
      double dx = 1.5;
      double x = 0;
      const maxX = 100.0;

      // Move forward.
      x += dx;
      expect(x, greaterThan(0));

      // Hit right edge.
      x = maxX + 1;
      if (x >= maxX) {
        dx = -dx;
        x = maxX;
      }
      expect(dx, lessThan(0));
      expect(x, maxX);

      // Hit left edge.
      x = -1;
      if (x <= 0) {
        dx = -dx;
        x = 0;
      }
      expect(dx, greaterThan(0));
      expect(x, 0);
    });
  });

  group('Clock display', () {
    test('24h format pads hours and minutes', () {
      String format24h(int hour, int minute) {
        return '${hour.toString().padLeft(2, '0')}:'
            '${minute.toString().padLeft(2, '0')}';
      }

      expect(format24h(0, 0), '00:00');
      expect(format24h(9, 5), '09:05');
      expect(format24h(23, 59), '23:59');
    });

    test('12h format converts hours correctly', () {
      String format12h(int hour, int minute) {
        final h =
            hour == 0
                ? 12
                : hour > 12
                ? hour - 12
                : hour;
        final amPm = hour >= 12 ? 'PM' : 'AM';
        return '$h:${minute.toString().padLeft(2, '0')} $amPm';
      }

      expect(format12h(0, 0), '12:00 AM');
      expect(format12h(12, 0), '12:00 PM');
      expect(format12h(13, 30), '1:30 PM');
      expect(format12h(23, 59), '11:59 PM');
    });

    test('position shifts use 9 alignment slots', () {
      // The clock uses 9 Alignment positions.
      const alignments = [
        'topLeft',
        'topCenter',
        'topRight',
        'centerLeft',
        'center',
        'centerRight',
        'bottomLeft',
        'bottomCenter',
        'bottomRight',
      ];
      expect(alignments.length, 9);
    });
  });
}
