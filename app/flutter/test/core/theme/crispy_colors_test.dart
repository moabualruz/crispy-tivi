import 'dart:ui';

import 'package:crispy_tivi/core/theme/crispy_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrispyColors Sprint 2 design tokens', () {
    test('scrim60 has 60% opacity black', () {
      expect(CrispyColors.scrim60, const Color(0x99000000));
    });

    test('scrim80 has 80% opacity black', () {
      expect(CrispyColors.scrim80, const Color(0xCC000000));
    });

    test('osdPanel has 70% opacity black', () {
      expect(CrispyColors.osdPanel, const Color(0xB3000000));
    });

    test('osdPanelDense has 85% dark panel', () {
      expect(CrispyColors.osdPanelDense, const Color(0xD91A1A1A));
    });

    test('segmentHighlight has 50% amber', () {
      expect(CrispyColors.segmentHighlight, const Color(0x80FFB300));
    });
  });
}
