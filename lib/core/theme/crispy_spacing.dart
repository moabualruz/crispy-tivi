/// Consistent spacing scale used throughout CrispyTivi.
///
/// Matches `.ai/docs/project-specs/design_system.md §1.4`. Never use raw pixel
/// values — always reference these tokens.
///
/// ```dart
/// padding: EdgeInsets.all(CrispySpacing.md),
/// SizedBox(height: CrispySpacing.sm),
/// ```
abstract final class CrispySpacing {
  /// 2 px — hairline gaps, tight inline separators.
  static const double xxs = 2;

  /// 4 px — icon padding, inline gaps.
  static const double xs = 4;

  /// 8 px — compact spacing, chip padding.
  static const double sm = 8;

  /// 16 px — default padding, card insets.
  static const double md = 16;

  /// 24 px — section spacing.
  static const double lg = 24;

  /// 32 px — large section gaps.
  static const double xl = 32;

  /// 48 px — page-level margins, hero spacing.
  static const double xxl = 48;
}
