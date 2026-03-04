part of 'memory_backend.dart';

/// Parser stubs and Stalker parser stubs
/// for [MemoryBackend].
mixin _MemoryParsersMixin on _MemoryStorage {
  // ── Parsers ────────────────────────────────────

  Future<Map<String, dynamic>> parseM3u(String content) async => {
    'channels': <Map<String, dynamic>>[],
  };

  Future<List<Map<String, dynamic>>> parseEpg(String content) async => [];

  Future<Map<String, String>> extractEpgChannelNames(String content) async =>
      {};

  Future<List<Map<String, dynamic>>> parseVodStreams(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
    String? sourceId,
  }) async => [];

  Future<List<Map<String, dynamic>>> parseSeries(
    String json, {
    String? sourceId,
  }) async => [];

  Future<List<Map<String, dynamic>>> parseEpisodes(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
    required String seriesId,
  }) async => [];

  Future<List<Map<String, dynamic>>> parseM3uVod(
    String json, {
    String? sourceId,
  }) async => [];

  Future<Map<String, dynamic>?> parseVttThumbnails(
    String content,
    String baseUrl,
  ) async => null;

  // ── Stalker Parsers ────────────────────────────

  Future<String> parseStalkerEpg(String json, String channelId) async => '[]';

  Future<String> parseStalkerVodItems(
    String json,
    String baseUrl, {
    String vodType = 'movie',
  }) async => '[]';

  Future<String> parseStalkerChannels(String json) async =>
      '{"items":[],"total_items":0,'
      '"max_page_items":25}';

  Future<String> parseStalkerLiveStreams(
    String json,
    String sourceId,
    String baseUrl,
  ) async => '[]';

  String buildStalkerStreamUrl(String cmd, String baseUrl) => '';

  Future<String?> parseStalkerCreateLink(String json, String baseUrl) async =>
      null;

  Future<String> parseStalkerCategories(String json) async => '[]';

  Future<String> parseStalkerVodResult(String json) async =>
      '{"items":[],"total_items":0,'
      '"max_page_items":25}';

  // ── Xtream Parsers ─────────────────────────────

  Future<String> parseXtreamShortEpg(
    String listingsJson,
    String channelId,
  ) async => '[]';

  Future<String> buildCategoryMap(String categoriesJson) async => '{}';

  Future<String> parseXtreamLiveStreams(
    String json, {
    required String baseUrl,
    required String username,
    required String password,
  }) async => '[]';

  Future<String> parseXtreamCategories(String json) async => '[]';

  Future<String> searchContent({
    required String query,
    required String channelsJson,
    required String vodItemsJson,
    required String epgEntriesJson,
    required String filterJson,
  }) async =>
      '{"channels":[],"movies":[],'
      '"series":[],"epg_programs":[]}';

  // ── S3 Parser ──────────────────────────────────

  Future<String> parseS3ListObjects(String xml) async => '[]';

  // ── Search Enrichment ──────────────────────────

  Future<String> enrichSearchResults(
    String resultsJson,
    String channelsJson,
    String vodItemsJson,
  ) async => '[]';
}
