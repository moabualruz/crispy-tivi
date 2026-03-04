import '../entities/epg_entry.dart';

/// Repository contract for EPG (program guide) data operations.
///
/// Implemented by infrastructure layer with local ObjectBox
/// storage and XMLTV parser.
abstract interface class EpgRepository {
  /// Returns EPG entries for a channel within a date range.
  Future<List<EpgEntry>> getPrograms({
    required String channelId,
    required DateTime from,
    required DateTime to,
  });

  /// Returns the currently-airing programme for a channel.
  Future<EpgEntry?> getNowPlaying(String channelId);

  /// Returns the next N upcoming programmes for a channel.
  Future<List<EpgEntry>> getUpcoming(String channelId, {int limit = 5});

  /// Fuzzy search across programme titles and descriptions.
  Future<List<EpgEntry>> search(String query);

  /// Deletes EPG entries older than [maxAge].
  Future<int> evictStale(Duration maxAge);
}
