import 'package:flutter/foundation.dart';

/// Why an item was recommended.
enum RecommendationReasonType {
  /// Similar to a recently watched item.
  becauseYouWatched,

  /// Popular content in a genre the user likes.
  popularInGenre,

  /// Trending across all users recently.
  trending,

  /// Recently added content matching user prefs.
  newForYou,

  /// Top composite-scored pick for this user.
  topPick,

  /// Fallback for new users with little history.
  coldStart,
}

/// Explains why a particular item was recommended.
@immutable
class RecommendationReason {
  const RecommendationReason({
    required this.type,
    this.sourceItemName,
    this.genreName,
  });

  /// The algorithm that produced this recommendation.
  final RecommendationReasonType type;

  /// Source item name (for [becauseYouWatched]).
  final String? sourceItemName;

  /// Genre/category name (for [popularInGenre]).
  final String? genreName;

  /// Human-readable explanation.
  String get displayText {
    switch (type) {
      case RecommendationReasonType.becauseYouWatched:
        return 'Because you watched'
            ' ${sourceItemName ?? ""}';
      case RecommendationReasonType.popularInGenre:
        return 'Popular in ${genreName ?? ""}';
      case RecommendationReasonType.trending:
        return 'Trending now';
      case RecommendationReasonType.newForYou:
        return 'New for you';
      case RecommendationReasonType.topPick:
        return 'Top pick for you';
      case RecommendationReasonType.coldStart:
        return 'Popular right now';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationReason &&
          type == other.type &&
          sourceItemName == other.sourceItemName &&
          genreName == other.genreName;

  @override
  int get hashCode => Object.hash(type, sourceItemName, genreName);

  @override
  String toString() => 'RecommendationReason($type, $displayText)';
}

/// A single recommended content item with scoring.
@immutable
class Recommendation {
  const Recommendation({
    required this.itemId,
    required this.itemName,
    required this.mediaType,
    required this.reason,
    required this.score,
    this.posterUrl,
    this.category,
    this.streamUrl,
    this.rating,
    this.year,
    this.seriesId,
  });

  /// ID of the recommended VOD item or channel.
  final String itemId;

  /// Display name.
  final String itemName;

  /// Content type: 'movie', 'series', or 'channel'.
  final String mediaType;

  /// Why this was recommended.
  final RecommendationReason reason;

  /// Relevance score (0.0–1.0, higher = better).
  final double score;

  /// Poster image URL.
  final String? posterUrl;

  /// Category / genre.
  final String? category;

  /// Stream URL for direct playback.
  final String? streamUrl;

  /// Content rating string.
  final String? rating;

  /// Release year.
  final int? year;

  /// Series ID (for episode recommendations).
  final String? seriesId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recommendation &&
          itemId == other.itemId &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(itemId, reason);

  @override
  String toString() =>
      'Recommendation($itemName, '
      'score=${score.toStringAsFixed(2)}, '
      '${reason.displayText})';
}

/// A titled group of recommendations for UI display.
@immutable
class RecommendationSection {
  const RecommendationSection({
    required this.title,
    required this.reasonType,
    required this.items,
    this.dynamicTitle,
  });

  /// Section display title (static label or backend-computed).
  final String title;

  /// Optional personalised title that overrides [title] in the UI.
  ///
  /// When non-null, this value is shown instead of [title]. Use this
  /// for "Because you watched [Movie]" style labels where the source
  /// item name is embedded in the string at generation time.
  final String? dynamicTitle;

  /// The reason type for all items in this section.
  final RecommendationReasonType reasonType;

  /// Recommended items, ordered by score descending.
  final List<Recommendation> items;

  /// The label shown in the UI — [dynamicTitle] if present,
  /// otherwise [title].
  String get displayTitle => dynamicTitle ?? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationSection &&
          title == other.title &&
          reasonType == other.reasonType;

  @override
  int get hashCode => Object.hash(title, reasonType);

  @override
  String toString() =>
      'RecommendationSection($displayTitle, '
      '${items.length} items)';
}
