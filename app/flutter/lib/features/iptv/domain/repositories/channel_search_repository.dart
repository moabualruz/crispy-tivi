import '../entities/channel.dart';
import '../entities/epg_entry.dart';

/// Repository contract for EPG-aware channel search operations.
///
/// Implemented by the infrastructure layer backed by the Rust
/// crispy-core engine via CacheService.
abstract interface class ChannelSearchRepository {
  // ── EPG-aware Search ───────────────────────────────

  /// Return channel IDs whose currently-airing program title matches [query].
  Future<List<String>> searchChannelsByLiveProgram(
    Map<String, List<EpgEntry>> epgEntries,
    String query,
    int nowMs,
  );

  /// Merge EPG-matched channels into the base filtered list.
  Future<List<Channel>> mergeEpgMatchedChannels({
    required List<Channel> baseChannels,
    required List<Channel> allChannels,
    required List<String> matchedIds,
    required Map<String, String> epgOverrides,
  });
}
