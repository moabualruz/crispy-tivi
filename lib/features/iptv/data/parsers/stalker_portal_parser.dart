import 'dart:convert';

import '../../../../core/data/cache_service.dart';
import '../../../../core/data/crispy_backend.dart';
import '../../domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';
import 'stalker_portal_result.dart';

/// Response-parsing methods for [StalkerPortalClient].
///
/// Delegates JSON parsing to the Rust [CrispyBackend]
/// and converts raw maps into domain objects.
mixin StalkerPortalParser {
  /// Rust backend for parsing delegation.
  CrispyBackend get parserBackend;

  /// Normalized base URL (scheme://host:port).
  String get baseUrl;

  /// Parses categories from Stalker genres response
  /// entirely in Dart.
  Future<List<Map<String, dynamic>>> parseCategories(dynamic data) async {
    if (data == null) return [];

    dynamic target = data;
    if (data is Map<String, dynamic> && data.containsKey('js')) {
      target = data['js'];
    }

    if (target is List) {
      return target.whereType<Map<String, dynamic>>().toList();
    } else if (target is Map<String, dynamic>) {
      // In PHP, an empty array is sometimes serialized as [],
      // but an associative array as {}.
      return target.values.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Parses channels result from Stalker ordered list
  /// response via Rust backend.
  Future<StalkerChannelsResult> parseChannelsResult(dynamic data) async {
    if (data == null) {
      return const StalkerChannelsResult(channels: []);
    }
    final result = await parserBackend.parseStalkerChannels(jsonEncode(data));
    final map = jsonDecode(result) as Map<String, dynamic>;
    final totalItems = map['total_items'] as int? ?? 0;
    final maxPageItems = map['max_page_items'] as int? ?? 25;
    final dataList = map['data'] as List<dynamic>? ?? [];
    return StalkerChannelsResult(
      channels: dataList,
      totalItems: totalItems,
      maxPageItems: maxPageItems,
    );
  }

  /// Parses Stalker channel list JSON into [Channel]
  /// list via Rust backend.
  Future<List<Channel>> parseLiveStreams(
    List<dynamic> data, {
    required String sourceId,
  }) async {
    final result = await parserBackend.parseStalkerLiveStreams(
      jsonEncode(data),
      sourceId,
      baseUrl,
    );
    final list = jsonDecode(result) as List<dynamic>;
    return list.map((m) => mapToChannel(m as Map<String, dynamic>)).toList();
  }

  /// Parses VOD result from Stalker ordered list
  /// response via Rust backend.
  Future<StalkerVodResult> parseVodResult(dynamic data) async {
    if (data == null) {
      return const StalkerVodResult(items: []);
    }
    final result = await parserBackend.parseStalkerVodResult(jsonEncode(data));
    final map = jsonDecode(result) as Map<String, dynamic>;
    final totalItems = map['total_items'] as int? ?? 0;
    final maxPageItems = map['max_page_items'] as int? ?? 25;
    final dataList = map['data'] as List<dynamic>? ?? [];
    return StalkerVodResult(
      items: dataList,
      totalItems: totalItems,
      maxPageItems: maxPageItems,
    );
  }

  /// Parses Stalker VOD list JSON into [VodItem] list
  /// via Rust backend.
  Future<List<VodItem>> parseVodItems(
    List<dynamic> data, {
    VodType type = VodType.movie,
  }) async {
    final result = await parserBackend.parseStalkerVodItems(
      jsonEncode(data),
      baseUrl,
      vodType: type.name,
    );
    final list = jsonDecode(result) as List<dynamic>;
    return list.map((m) => mapToVodItem(m as Map<String, dynamic>)).toList();
  }

  /// Parses create_link response to extract the
  /// authenticated stream URL via Rust backend.
  Future<String?> parseCreateLinkResponse(dynamic data) async {
    if (data == null) return null;
    return parserBackend.parseStalkerCreateLink(jsonEncode(data), baseUrl);
  }
}
