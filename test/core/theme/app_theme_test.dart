import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/crispy_colors.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Disable font loading for unit tests
  AppTheme.useGoogleFonts = false;

  group('AppTheme Cinematic Dark Mode', () {
    test('Should Use Pure Black for Scaffold Background', () {
      final theme = AppTheme.fromSeedHex('#3B82F6').theme;
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
    });

    test('Should Use Dark Surface (121212) for Panels', () {
      final theme = AppTheme.fromSeedHex('#3B82F6').theme;
      expect(theme.cardTheme.color, const Color(0xFF121212));
      expect(theme.appBarTheme.backgroundColor, const Color(0xFF121212));
      expect(theme.bottomSheetTheme.backgroundColor, const Color(0xFF121212));
    });

    test('Should Use Design System Radius Tokens', () {
      final theme = AppTheme.fromSeedHex('#3B82F6').theme;

      // Cards use CrispyRadius.md (12)
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(cardShape.borderRadius, BorderRadius.circular(CrispyRadius.md));

      // Inputs use CrispyRadius.sm (8)
      final inputBorder =
          theme.inputDecorationTheme.border as OutlineInputBorder;
      expect(inputBorder.borderRadius, BorderRadius.circular(CrispyRadius.sm));

      // Dialogs use CrispyRadius.lg (16)
      final dialogShape = theme.dialogTheme.shape as RoundedRectangleBorder?;
      if (dialogShape != null) {
        expect(
          dialogShape.borderRadius,
          BorderRadius.circular(CrispyRadius.lg),
        );
      }
    });

    test('Should Have Correct CrispyColors', () {
      final theme = AppTheme.fromSeedHex('#3B82F6').theme;
      final crispy = theme.crispyColors;

      expect(crispy.liveRed, const Color(0xFFFF5252));
      expect(crispy.epgNowLine, const Color(0xFFFF0000));
    });
  });
}
