import 'package:meta/meta.dart';

/// A single EPG (Electronic Program Guide) entry.
///
/// Domain entity — pure Dart. Maps to a `<programme>` element
/// in an XMLTV file. Keyed by [channelId] + [startTime].
@immutable
class EpgEntry {
  const EpgEntry({
    required this.channelId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.category,
    this.iconUrl,
  });

  /// TVG ID linking this entry to a [Channel].
  final String channelId;

  /// Programme title.
  final String title;

  /// Start time (UTC).
  final DateTime startTime;

  /// End time (UTC).
  final DateTime endTime;

  /// Optional programme description / synopsis.
  final String? description;

  /// Optional programme category (e.g., "Movie", "Sports").
  final String? category;

  /// Optional programme icon/poster URL.
  final String? iconUrl;

  /// Programme duration.
  Duration get duration => endTime.difference(startTime);

  /// Whether this programme is currently airing.
  ///
  /// Pass [now] to override the current time (useful for
  /// deterministic tests).
  bool isLiveAt([DateTime? now]) {
    final t = (now ?? DateTime.now()).toUtc();
    return !t.isBefore(startTime) && t.isBefore(endTime);
  }

  /// Convenience getter that delegates to [isLiveAt].
  bool get isLive => isLiveAt();

  /// Progress ratio (0.0 – 1.0) if currently airing,
  /// else 0.
  ///
  /// Pass [now] to override the current time.
  double progressAt([DateTime? now]) {
    if (!isLiveAt(now)) return 0.0;
    final t = (now ?? DateTime.now()).toUtc();
    final elapsed = t.difference(startTime).inSeconds;
    final total = duration.inSeconds;
    if (total == 0) return 0.0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// Convenience getter that delegates to [progressAt].
  double get progress => progressAt();

  /// Whether this programme has ended.
  ///
  /// Pass [now] to override the current time.
  bool isPastAt([DateTime? now]) {
    return (now ?? DateTime.now()).toUtc().isAfter(endTime);
  }

  /// Convenience getter that delegates to [isPastAt].
  bool get isPast => isPastAt();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpgEntry &&
          runtimeType == other.runtimeType &&
          channelId == other.channelId &&
          startTime == other.startTime;

  @override
  int get hashCode => Object.hash(channelId, startTime);

  @override
  String toString() => 'EpgEntry($title, $startTime\u2013$endTime)';
}
