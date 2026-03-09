import 'package:flutter/material.dart';

/// Main color options for dark theme surface.
///
/// Each hue provides a different atmospheric base while maintaining
/// readability. See `.ai/docs/project-specs/design_system.md §1.2` for details.
enum MainColorHue {
  /// Pure dark (#0F0F0F) — Pure dark, OLED-friendly.
  pureBlack,

  /// Material dark (#121212) — Default warm gray.
  warmBlack,

  /// Blue-tinted dark (#0A1929) — Midnight, cool.
  coolBlack,

  /// Green-tinted dark (#0D1117) — GitHub dark, forest.
  greenBlack,

  /// Purple-tinted dark (#13111C) — Twilight, creative.
  purpleBlack,
}

/// Extension providing color values for each [MainColorHue].
extension MainColorHueColors on MainColorHue {
  /// The main surface color for this hue.
  Color get surface {
    switch (this) {
      case MainColorHue.pureBlack:
        return const Color(0xFF0F0F0F);
      case MainColorHue.warmBlack:
        return const Color(0xFF121212);
      case MainColorHue.coolBlack:
        return const Color(0xFF0A1929);
      case MainColorHue.greenBlack:
        return const Color(0xFF0D1117);
      case MainColorHue.purpleBlack:
        return const Color(0xFF13111C);
    }
  }

  /// The raised surface color (cards, panels) for this hue.
  Color get raised {
    switch (this) {
      case MainColorHue.pureBlack:
        return const Color(0xFF1A1A1A);
      case MainColorHue.warmBlack:
        return const Color(0xFF1E1E1E);
      case MainColorHue.coolBlack:
        return const Color(0xFF132F4C);
      case MainColorHue.greenBlack:
        return const Color(0xFF161B22);
      case MainColorHue.purpleBlack:
        return const Color(0xFF1D1A27);
    }
  }

  /// The surface container high color for this hue.
  Color get surfaceContainerHigh {
    switch (this) {
      case MainColorHue.pureBlack:
        return const Color(0xFF262626);
      case MainColorHue.warmBlack:
        return const Color(0xFF2A2A2A);
      case MainColorHue.coolBlack:
        return const Color(0xFF1E3A5F);
      case MainColorHue.greenBlack:
        return const Color(0xFF21262D);
      case MainColorHue.purpleBlack:
        return const Color(0xFF282433);
    }
  }

  /// The scaffold background (typically darker than surface).
  Color get scaffold {
    switch (this) {
      case MainColorHue.pureBlack:
        return const Color(0xFF000000);
      case MainColorHue.warmBlack:
        return const Color(0xFF0A0A0A);
      case MainColorHue.coolBlack:
        return const Color(0xFF061220);
      case MainColorHue.greenBlack:
        return const Color(0xFF0A0D10);
      case MainColorHue.purpleBlack:
        return const Color(0xFF0E0C14);
    }
  }

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case MainColorHue.pureBlack:
        return 'Pure Black';
      case MainColorHue.warmBlack:
        return 'Warm Black';
      case MainColorHue.coolBlack:
        return 'Cool Midnight';
      case MainColorHue.greenBlack:
        return 'Forest Dark';
      case MainColorHue.purpleBlack:
        return 'Twilight';
    }
  }

  /// Descriptive label for settings UI.
  String get description {
    switch (this) {
      case MainColorHue.pureBlack:
        return 'Pure dark, OLED-friendly';
      case MainColorHue.warmBlack:
        return 'Material Design default';
      case MainColorHue.coolBlack:
        return 'Blue-tinted, cool atmosphere';
      case MainColorHue.greenBlack:
        return 'GitHub-style, nature tones';
      case MainColorHue.purpleBlack:
        return 'Purple-tinted, creative mood';
    }
  }

  /// Preview swatch color for theme picker.
  Color get previewColor => surface;
}
