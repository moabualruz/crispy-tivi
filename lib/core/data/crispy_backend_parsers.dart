part of 'crispy_backend.dart';

/// Parser methods for M3U, EPG, Xtream, Stalker, VTT,
/// and S3 content.
///
/// Implemented by [CrispyBackend] via `implements`.
abstract class _BackendParserMethods {
  // ── M3U / EPG Parsers ────────────────────────────────

  /// Parse M3U/M3U8 playlist content via Rust.
  /// Returns {channels: [...], epg_url: String?}.
  Future<Map<String, dynamic>> parseM3u(String content);

  /// Parse XMLTV EPG content via Rust.
  /// Returns list of EPG entry maps.
  Future<List<Map<String, dynamic>>> parseEpg(String content);

  /// Extract XMLTV channel display names via Rust.
  /// Returns {xmltv_id: display_name}.
  Future<Map<String, String>> extractEpgChannelNames(String content);

  // ── Xtream Parsers ───────────────────────────────────

  /// Parse Xtream get_vod_streams response via Rust.
  Future<List<Map<String, dynamic>>> parseVodStreams(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
    String? sourceId,
  });

  /// Parse Xtream get_series response via Rust.
  Future<List<Map<String, dynamic>>> parseSeries(
    String json, {
    String? sourceId,
  });

  /// Parse episodes from get_series_info via Rust.
  Future<List<Map<String, dynamic>>> parseEpisodes(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
    required String seriesId,
  });

  /// Parse VOD from M3U channel maps via Rust.
  Future<List<Map<String, dynamic>>> parseM3uVod(
    String json, {
    String? sourceId,
  });

  /// Parse WebVTT thumbnail sprite sheet via Rust.
  /// Returns sprite map or null if invalid.
  Future<Map<String, dynamic>?> parseVttThumbnails(
    String content,
    String baseUrl,
  );

  // ── Stalker Parsers ──────────────────────────────────

  /// Parse Stalker EPG entries for a channel.
  /// Returns JSON array of EPG entry objects.
  Future<String> parseStalkerEpg(String json, String channelId);

  /// Parse Stalker VOD items list.
  /// Returns JSON array of VodItem objects.
  Future<String> parseStalkerVodItems(
    String json,
    String baseUrl, {
    String vodType = 'movie',
  });

  /// Parse Stalker channels paginated result.
  /// Returns JSON of paginated result.
  Future<String> parseStalkerChannels(String json);

  /// Parse Stalker live streams into channels.
  /// Returns JSON array of Channel objects.
  Future<String> parseStalkerLiveStreams(
    String json,
    String sourceId,
    String baseUrl,
  );

  /// Build a stream URL from a Stalker `cmd` field.
  /// Returns the resolved URL string.
  String buildStalkerStreamUrl(String cmd, String baseUrl);

  /// Parse a Stalker `create_link` response.
  /// Returns authenticated stream URL or null.
  Future<String?> parseStalkerCreateLink(String json, String baseUrl);

  /// Parse Stalker categories JSON into a sorted list.
  /// Returns JSON array of category name strings.
  Future<String> parseStalkerCategories(String json);

  /// Parse Stalker VOD paginated result.
  /// Returns JSON of paginated result.
  Future<String> parseStalkerVodResult(String json);

  // ── Xtream Parsers (Phase 7-8) ───────────────────────

  /// Parse Xtream short EPG listings.
  /// Returns JSON array of EPG entry objects.
  Future<String> parseXtreamShortEpg(String listingsJson, String channelId);

  /// Parse Xtream live streams JSON into channels.
  /// Returns JSON array of Channel.
  Future<String> parseXtreamLiveStreams(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
  });

  /// Parse Xtream categories into sorted names.
  /// Returns JSON array of strings.
  Future<String> parseXtreamCategories(String json);

  // ── S3 Parser ────────────────────────────────────────

  /// Parse S3 ListBucketResult XML response.
  /// Returns JSON array of S3Object.
  Future<String> parseS3ListObjects(String xml);

  // ── Recommendation Parsers ───────────────────────────

  /// Parse recommendation sections into typed structs.
  /// Returns JSON array of TypedRecommendationSection.
  Future<String> parseRecommendationSections(String sectionsJson);

  /// Deserialize recommendation sections into
  /// fully-merged structs with typed enums and all
  /// supplementary fields (poster, category, etc.).
  /// Returns JSON array of FullRecommendationSection.
  Future<String> deserializeRecommendationSections(String sectionsJson);
}
