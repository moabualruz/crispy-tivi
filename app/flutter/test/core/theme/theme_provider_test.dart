import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/theme/accent_color.dart';
import 'package:crispy_tivi/core/theme/main_color_hue.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';

void main() {
  // ── ThemeState unit tests ────────────────────────

  group('ThemeState', () {
    test('default values are correct', () {
      const state = ThemeState();

      expect(state.mainHue, MainColorHue.warmBlack);
      expect(state.accent, AccentColor.gray);
      expect(state.customAccent, isNull);
      expect(state.textScale, 1.0);
      expect(state.density, UiDensity.standard);
      expect(state.glassOpacity, 1.0);
    });

    test('copyWith preserves all fields', () {
      final original = ThemeState(
        mainHue: MainColorHue.coolBlack,
        accent: AccentColor.teal,
        customAccent: const Color(0xFFFF0000),
        textScale: 1.2,
        density: UiDensity.compact,
        glassOpacity: 0.5,
      );

      final copy = original.copyWith();

      expect(copy.mainHue, MainColorHue.coolBlack);
      expect(copy.accent, AccentColor.teal);
      expect(copy.customAccent, isNotNull);
      expect(copy.textScale, 1.2);
      expect(copy.density, UiDensity.compact);
      expect(copy.glassOpacity, 0.5);
    });

    test('copyWith replaces specific fields', () {
      const original = ThemeState();

      final copy = original.copyWith(
        mainHue: MainColorHue.pureBlack,
        accent: AccentColor.red,
        textScale: 0.9,
        density: UiDensity.comfortable,
        glassOpacity: 0.0,
      );

      expect(copy.mainHue, MainColorHue.pureBlack);
      expect(copy.accent, AccentColor.red);
      expect(copy.textScale, 0.9);
      expect(copy.density, UiDensity.comfortable);
      expect(copy.glassOpacity, 0.0);
    });

    test('copyWith clearCustomAccent removes '
        'custom color', () {
      final original = ThemeState(customAccent: const Color(0xFF00FF00));

      final copy = original.copyWith(clearCustomAccent: true);

      expect(copy.customAccent, isNull);
    });

    test('copyWith clearCustomAccent ignores new '
        'customAccent', () {
      final original = ThemeState(customAccent: const Color(0xFF00FF00));

      final copy = original.copyWith(
        clearCustomAccent: true,
        customAccent: const Color(0xFFFF0000),
      );

      // clearCustomAccent takes precedence.
      expect(copy.customAccent, isNull);
    });

    // ── Derived color properties ───────────────────

    test('primaryColor returns accent color for '
        'non-custom presets', () {
      const state = ThemeState(accent: AccentColor.blue);

      expect(state.primaryColor, AccentColor.blue.color);
    });

    test('primaryColor returns custom color when '
        'accent is custom', () {
      const custom = Color(0xFFABCDEF);
      const state = ThemeState(
        accent: AccentColor.custom,
        customAccent: custom,
      );

      expect(state.primaryColor, custom);
    });

    test('primaryColor falls back to blue when '
        'custom is null', () {
      const state = ThemeState(accent: AccentColor.custom);

      // Fallback: 0xFF3B82F6 (blue default).
      expect(state.primaryColor, const Color(0xFF3B82F6));
    });

    test('primaryContainer returns accent container '
        'for presets', () {
      const state = ThemeState(accent: AccentColor.red);

      expect(state.primaryContainer, AccentColor.red.container);
    });

    test('onPrimaryContainer returns accent '
        'onContainer for presets', () {
      const state = ThemeState(accent: AccentColor.teal);

      expect(state.onPrimaryContainer, AccentColor.teal.onContainer);
    });

    test('surface delegates to mainHue', () {
      const state = ThemeState(mainHue: MainColorHue.coolBlack);

      expect(state.surface, MainColorHue.coolBlack.surface);
    });

    test('surfaceContainer delegates to mainHue '
        'raised', () {
      const state = ThemeState(mainHue: MainColorHue.greenBlack);

      expect(state.surfaceContainer, MainColorHue.greenBlack.raised);
    });

    test('scaffoldBackground delegates to mainHue', () {
      const state = ThemeState(mainHue: MainColorHue.purpleBlack);

      expect(state.scaffoldBackground, MainColorHue.purpleBlack.scaffold);
    });
  });

  // ── UiDensity ────────────────────────────────────

  group('UiDensity', () {
    test('has three presets', () {
      expect(UiDensity.values, hasLength(3));
    });

    test('labels are non-empty', () {
      for (final d in UiDensity.values) {
        expect(d.label, isNotEmpty, reason: '${d.name} should have label');
      }
    });

    test('compact visualDensity is VisualDensity.compact', () {
      expect(UiDensity.compact.visualDensity, VisualDensity.compact);
    });

    test('standard visualDensity is '
        'VisualDensity.standard', () {
      expect(UiDensity.standard.visualDensity, VisualDensity.standard);
    });

    test('comfortable visualDensity is '
        'VisualDensity.comfortable', () {
      expect(UiDensity.comfortable.visualDensity, VisualDensity.comfortable);
    });
  });

  // ── AccentColor ──────────────────────────────────

  group('AccentColor', () {
    test('all non-custom accents have a color', () {
      for (final a in AccentColor.values) {
        if (a == AccentColor.custom) continue;
        expect(a.color, isNotNull, reason: '${a.name} should have a color');
      }
    });

    test('custom accent color is null', () {
      expect(AccentColor.custom.color, isNull);
    });

    test('all non-custom accents have container '
        'colors', () {
      for (final a in AccentColor.values) {
        if (a == AccentColor.custom) continue;
        expect(
          a.container,
          isNotNull,
          reason: '${a.name} should have container',
        );
        expect(
          a.onContainer,
          isNotNull,
          reason: '${a.name} should have onContainer',
        );
      }
    });

    test('displayName is non-empty for all', () {
      for (final a in AccentColor.values) {
        expect(a.displayName, isNotEmpty, reason: '${a.name} displayName');
      }
    });

    test('description is non-empty for all', () {
      for (final a in AccentColor.values) {
        expect(a.description, isNotEmpty, reason: '${a.name} description');
      }
    });
  });

  // ── MainColorHue ─────────────────────────────────

  group('MainColorHue', () {
    test('has five hue options', () {
      expect(MainColorHue.values, hasLength(5));
    });

    test('all hues have distinct surface colors', () {
      final surfaces = MainColorHue.values.map((h) => h.surface).toSet();
      expect(
        surfaces.length,
        MainColorHue.values.length,
        reason: 'Each hue should have unique surface',
      );
    });

    test('all hues have non-empty displayName', () {
      for (final h in MainColorHue.values) {
        expect(h.displayName, isNotEmpty, reason: '${h.name} displayName');
      }
    });

    test('scaffold is darker than surface for all', () {
      for (final h in MainColorHue.values) {
        // Compare luminance: scaffold should be
        // darker (lower luminance) than surface.
        final scaffoldL = HSLColor.fromColor(h.scaffold).lightness;
        final surfaceL = HSLColor.fromColor(h.surface).lightness;

        expect(
          scaffoldL,
          lessThanOrEqualTo(surfaceL),
          reason:
              '${h.name} scaffold should be '
              'darker than surface',
        );
      }
    });

    test('raised is lighter than surface for all', () {
      for (final h in MainColorHue.values) {
        final raisedL = HSLColor.fromColor(h.raised).lightness;
        final surfaceL = HSLColor.fromColor(h.surface).lightness;

        expect(
          raisedL,
          greaterThanOrEqualTo(surfaceL),
          reason:
              '${h.name} raised should be '
              'lighter than surface',
        );
      }
    });
  });
}
