import 'package:flutter/material.dart';

import 'crispy_colors.dart';

/// Accent color options for primary actions and focus states.
///
/// See `the project design system documentation §1.3` for details.
enum AccentColor {
  /// Rice Blue (#3B82F6) — Default, calm.
  blue,

  /// Cinematic red (#E50914) — Bold, vibrant.
  red,

  /// Fresh teal (#00BFA5) — Modern, clean.
  teal,

  /// Warm orange (#FF6D00) — Energetic.
  orange,

  /// Bold purple (#AA00FF) — Creative.
  purple,

  /// Nature green (#00C853) — Positive, fresh.
  green,

  /// Neutral gray (#9E9E9E) — Subtle, minimal.
  gray,

  /// User-defined custom color.
  custom,
}

/// The canonical app accent palette — the six primary named accent colors,
/// ordered to match [AccentColor] (blue → red → teal → orange → purple → green).
///
/// Use this list wherever a fixed palette of app-wide accent swatches is
/// needed (e.g. profile accent pickers, theme demos) instead of repeating
/// the hex literals.
const List<Color> kAppAccentPalette = [
  Color(0xFF3B82F6), // blue
  CrispyColors.brandRed, // red
  Color(0xFF00BFA5), // teal
  Color(0xFFFF6D00), // orange
  Color(0xFFAA00FF), // purple
  Color(0xFF00C853), // green
];

/// Extension providing color values for each [AccentColor].
extension AccentColorValues on AccentColor {
  /// The primary accent color.
  ///
  /// Returns `null` for [AccentColor.custom] — use the custom color value
  /// from settings instead.
  Color? get color {
    switch (this) {
      case AccentColor.blue:
        return const Color(0xFF3B82F6);
      case AccentColor.red:
        return CrispyColors.brandRed;
      case AccentColor.teal:
        return const Color(0xFF00BFA5);
      case AccentColor.orange:
        return const Color(0xFFFF6D00);
      case AccentColor.purple:
        return const Color(0xFFAA00FF);
      case AccentColor.green:
        return const Color(0xFF00C853);
      case AccentColor.gray:
        return const Color(0xFFD1D5DB);
      case AccentColor.custom:
        return null;
    }
  }

  /// The container color for this accent (used for selections).
  Color? get container {
    switch (this) {
      case AccentColor.blue:
        return const Color(0xFF1E3A5F);
      case AccentColor.red:
        return const Color(0xFF4A0000);
      case AccentColor.teal:
        return const Color(0xFF004D40);
      case AccentColor.orange:
        return const Color(0xFFE65100);
      case AccentColor.purple:
        return const Color(0xFF4A148C);
      case AccentColor.green:
        return const Color(0xFF1B5E20);
      case AccentColor.gray:
        return const Color(0xFF374151);
      case AccentColor.custom:
        return null;
    }
  }

  /// The on-container color for text/icons on container.
  Color? get onContainer {
    switch (this) {
      case AccentColor.blue:
        return const Color(0xFFDBEAFE);
      case AccentColor.red:
        return const Color(0xFFFFCDD2);
      case AccentColor.teal:
        return const Color(0xFFB2DFDB);
      case AccentColor.orange:
        return const Color(0xFFFFE0B2);
      case AccentColor.purple:
        return const Color(0xFFE1BEE7);
      case AccentColor.green:
        return const Color(0xFFC8E6C9);
      case AccentColor.gray:
        return const Color(0xFFF3F4F6);
      case AccentColor.custom:
        return null;
    }
  }

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case AccentColor.blue:
        return 'Blue';
      case AccentColor.red:
        return 'Red';
      case AccentColor.teal:
        return 'Teal';
      case AccentColor.orange:
        return 'Orange';
      case AccentColor.purple:
        return 'Purple';
      case AccentColor.green:
        return 'Green';
      case AccentColor.gray:
        return 'Gray';
      case AccentColor.custom:
        return 'Custom';
    }
  }

  /// Descriptive label for settings UI.
  String get description {
    switch (this) {
      case AccentColor.blue:
        return 'Classic, calm';
      case AccentColor.red:
        return 'Vibrant, bold';
      case AccentColor.teal:
        return 'Fresh, modern';
      case AccentColor.orange:
        return 'Warm, energetic';
      case AccentColor.purple:
        return 'Creative, bold';
      case AccentColor.green:
        return 'Nature, positive';
      case AccentColor.gray:
        return 'Subtle, minimal';
      case AccentColor.custom:
        return 'Your choice';
    }
  }

  /// Preview swatch color for theme picker.
  Color? get previewColor => color;
}
