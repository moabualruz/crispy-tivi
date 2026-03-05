/// MPAA-based content rating levels for parental controls.
enum ContentRatingLevel {
  /// General Audiences - All ages admitted.
  g(0, 'G'),

  /// Parental Guidance Suggested.
  pg(1, 'PG'),

  /// Parents Strongly Cautioned - Some material may be inappropriate
  /// for children under 13.
  pg13(2, 'PG-13'),

  /// Restricted - Under 17 requires accompanying parent or adult guardian.
  r(3, 'R'),

  /// Adults Only - No one 17 and under admitted.
  nc17(4, 'NC-17'),

  /// No rating information available.
  unrated(5, 'Unrated');

  const ContentRatingLevel(this.value, this.code);

  /// Numeric value for comparison (lower = more restrictive).
  final int value;

  /// Display code for the rating.
  final String code;

  /// Parses a rating string into a ContentRatingLevel.
  ///
  /// Handles MPAA ratings (G, PG, PG-13, R, NC-17) and
  /// TV Parental Guidelines (TV-G, TV-PG, TV-14, TV-MA).
  static ContentRatingLevel fromString(String? rating) {
    if (rating == null || rating.isEmpty) return unrated;

    final s = rating.toUpperCase().trim();

    // NC-17 / TV-MA (most restrictive)
    if (s.contains('NC-17') || s == 'NC17') return nc17;
    if (s.contains('TV-MA') || s == 'TVMA') return nc17;

    // R rated
    if (s == 'R' || s == 'RATED R') return r;

    // PG-13 / TV-14
    if (s.contains('PG-13') || s == 'PG13') return pg13;
    if (s.contains('TV-14') || s == 'TV14') return pg13;

    // PG / TV-PG
    if (s == 'PG' || s == 'RATED PG') return pg;
    if (s.contains('TV-PG') || s == 'TVPG') return pg;

    // G / TV-G / TV-Y (most permissive)
    if (s == 'G' || s == 'RATED G') return g;
    if (s.contains('TV-G') || s == 'TVG') return g;
    if (s.contains('TV-Y')) return g;

    return unrated;
  }

  /// Returns human-readable description of the rating.
  String get description {
    switch (this) {
      case g:
        return 'General Audiences';
      case pg:
        return 'Parental Guidance Suggested';
      case pg13:
        return 'Parents Strongly Cautioned';
      case r:
        return 'Restricted';
      case nc17:
        return 'Adults Only';
      case unrated:
        return 'Not Rated';
    }
  }

  /// Checks if content with this rating is allowed for a given max level.
  bool isAllowedFor(ContentRatingLevel maxAllowed) {
    // Unrated content follows the max allowed rating
    if (this == unrated) return true;
    return value <= maxAllowed.value;
  }

  /// Returns the rating level from its numeric value.
  static ContentRatingLevel fromValue(int value) {
    return ContentRatingLevel.values.firstWhere(
      (r) => r.value == value,
      orElse: () => unrated,
    );
  }

  /// Display label used in UI dropdowns and pickers.
  ///
  /// NC-17 is shown as "All / Unrestricted" since it represents the
  /// unrestricted default cap for non-kids profiles.
  String get displayLabel {
    if (this == nc17) return 'All / Unrestricted';
    return '$code — $description';
  }
}
