import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../iptv/domain/entities/epg_entry.dart';

/// Codec for converting [EpgEntry] maps to/from the JSON
/// format expected by the Rust backend (`mergeEpgWindow`).
///
/// JSON shape:
/// ```json
/// {
///   "channelId": [
///     {
///       "channelId": "...",
///       "title": "...",
///       "startTime": 1700000000000,
///       "endTime":   1700003600000,
///       "description": "...",
///       "category": "...",
///       "iconUrl": "..."
///     }
///   ]
/// }
/// ```
/// All timestamps are epoch milliseconds (UTC).
abstract final class EpgJsonCodec {
  /// Encodes a channel→entries map to the Rust epoch-ms JSON format.
  static String encode(Map<String, List<EpgEntry>> entries) {
    final map = <String, dynamic>{};
    for (final kv in entries.entries) {
      map[kv.key] =
          kv.value
              .map(
                (e) => <String, dynamic>{
                  'channelId': e.channelId,
                  'title': e.title,
                  'startTime': e.startTime.millisecondsSinceEpoch,
                  'endTime': e.endTime.millisecondsSinceEpoch,
                  if (e.description != null) 'description': e.description,
                  if (e.category != null) 'category': e.category,
                  if (e.iconUrl != null) 'iconUrl': e.iconUrl,
                },
              )
              .toList();
    }
    return jsonEncode(map);
  }

  /// Decodes a Rust epoch-ms JSON string back to a channel→entries map.
  static Map<String, List<EpgEntry>> decode(String json) {
    final result = <String, List<EpgEntry>>{};
    try {
      final raw = jsonDecode(json) as Map<String, dynamic>;
      for (final kv in raw.entries) {
        final list = (kv.value as List).cast<Map<String, dynamic>>();
        result[kv.key] =
            list
                .map(
                  (m) => EpgEntry(
                    channelId: m['channelId'] as String? ?? kv.key,
                    title: m['title'] as String? ?? '',
                    startTime: DateTime.fromMillisecondsSinceEpoch(
                      m['startTime'] as int,
                      isUtc: true,
                    ),
                    endTime: DateTime.fromMillisecondsSinceEpoch(
                      m['endTime'] as int,
                      isUtc: true,
                    ),
                    description: m['description'] as String?,
                    category: m['category'] as String?,
                    iconUrl: m['iconUrl'] as String?,
                  ),
                )
                .toList();
      }
    } catch (e) {
      debugPrint('EpgJsonCodec: Failed to decode EPG entries: $e');
    }
    return result;
  }
}
