import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/utils/device_form_factor.dart';
import 'package:crispy_tivi/main.dart' show computeUiAutoScale;

void main() {
  group('DeviceFormFactor enum', () {
    test('desktop supportsAutoScale', () {
      expect(DeviceFormFactor.desktop.supportsAutoScale, isTrue);
    });

    test('androidTV supportsAutoScale', () {
      expect(DeviceFormFactor.androidTV.supportsAutoScale, isTrue);
    });

    test('androidPhone does not supportsAutoScale', () {
      expect(DeviceFormFactor.androidPhone.supportsAutoScale, isFalse);
    });

    test('androidTablet does not supportsAutoScale', () {
      expect(DeviceFormFactor.androidTablet.supportsAutoScale, isFalse);
    });

    test('iPad does not supportsAutoScale', () {
      expect(DeviceFormFactor.iPad.supportsAutoScale, isFalse);
    });

    test('iPhone does not supportsAutoScale', () {
      expect(DeviceFormFactor.iPhone.supportsAutoScale, isFalse);
    });

    test('web does not supportsAutoScale', () {
      expect(DeviceFormFactor.web.supportsAutoScale, isFalse);
    });

    test('isTV only true for androidTV', () {
      for (final ff in DeviceFormFactor.values) {
        expect(ff.isTV, ff == DeviceFormFactor.androidTV, reason: ff.name);
      }
    });

    test('isPhone true for androidPhone and iPhone', () {
      expect(DeviceFormFactor.androidPhone.isPhone, isTrue);
      expect(DeviceFormFactor.iPhone.isPhone, isTrue);
      expect(DeviceFormFactor.iPad.isPhone, isFalse);
      expect(DeviceFormFactor.desktop.isPhone, isFalse);
      expect(DeviceFormFactor.androidTV.isPhone, isFalse);
    });

    test('isTablet true for androidTablet and iPad', () {
      expect(DeviceFormFactor.androidTablet.isTablet, isTrue);
      expect(DeviceFormFactor.iPad.isTablet, isTrue);
      expect(DeviceFormFactor.androidPhone.isTablet, isFalse);
      expect(DeviceFormFactor.desktop.isTablet, isFalse);
    });

    test('isDesktop only true for desktop', () {
      for (final ff in DeviceFormFactor.values) {
        expect(ff.isDesktop, ff == DeviceFormFactor.desktop, reason: ff.name);
      }
    });

    test('isMobile true for phones and tablets only', () {
      expect(DeviceFormFactor.androidPhone.isMobile, isTrue);
      expect(DeviceFormFactor.iPhone.isMobile, isTrue);
      expect(DeviceFormFactor.androidTablet.isMobile, isTrue);
      expect(DeviceFormFactor.iPad.isMobile, isTrue);
      expect(DeviceFormFactor.desktop.isMobile, isFalse);
      expect(DeviceFormFactor.androidTV.isMobile, isFalse);
      expect(DeviceFormFactor.web.isMobile, isFalse);
    });
  });

  group('computeUiAutoScale with form factor guard', () {
    tearDown(() {
      // Reset to desktop so other tests aren't affected.
      DeviceFormFactorService.debugOverride = DeviceFormFactor.desktop;
    });

    test('returns 1.0 on androidPhone regardless of resolution', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.androidPhone;
      // Pixel 7: logical 914dp, DPR 2.625 → physical 2399px
      expect(computeUiAutoScale(914, 2.625), 1.0);
      // Even at 4K-level inputs
      expect(computeUiAutoScale(1080, 2.0), 1.0);
    });

    test('returns 1.0 on iPad regardless of resolution', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.iPad;
      // iPad Pro 12.9": logical 1024dp, DPR 2.0 → physical 2048px
      expect(computeUiAutoScale(1024, 2.0), 1.0);
    });

    test('returns 1.0 on androidTablet', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.androidTablet;
      expect(computeUiAutoScale(800, 2.0), 1.0);
    });

    test('returns 1.0 on iPhone', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.iPhone;
      expect(computeUiAutoScale(844, 3.0), 1.0);
    });

    test('returns 1.0 on web', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.web;
      expect(computeUiAutoScale(1080, 2.0), 1.0);
    });

    test('returns 1.0 on desktop below 1440px physical', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.desktop;
      // 1080p: 1080 * 1.0 = 1080px physical
      expect(computeUiAutoScale(1080, 1.0), 1.0);
    });

    test('returns > 1.0 on desktop above 1440px physical', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.desktop;
      // 4K: 2160 * 1.0 = 2160px physical → expect 2.0
      expect(computeUiAutoScale(2160, 1.0), 2.0);
    });

    test('returns > 1.0 on androidTV above 1440px physical', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.androidTV;
      // 4K TV: 2160 * 1.0 = 2160px physical → expect 2.0
      expect(computeUiAutoScale(2160, 1.0), 2.0);
    });

    test('returns exactly 1.0 at 1440px boundary on desktop', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.desktop;
      // Exactly 1440px: right at threshold
      expect(computeUiAutoScale(1440, 1.0), 1.0);
    });

    test('returns exactly 2.0 at 2160px on desktop', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.desktop;
      expect(computeUiAutoScale(2160, 1.0), 2.0);
    });

    test('scales linearly between 1440 and 2160 on desktop', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.desktop;
      // Midpoint: 1800px → 1.0 + (1800-1440)/720 = 1.5
      expect(computeUiAutoScale(1800, 1.0), 1.5);
    });

    test('continues scaling above 2160px on desktop', () {
      DeviceFormFactorService.debugOverride = DeviceFormFactor.desktop;
      // 8K: 4320px → 1.0 + (4320-1440)/720 = 5.0
      expect(computeUiAutoScale(4320, 1.0), 5.0);
    });
  });
}
