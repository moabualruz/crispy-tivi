import 'dart:convert';

import '../domain/segment_skip_config.dart';

/// Encodes a per-type skip config map to a JSON string for persistence.
///
/// Lives in data layer because it uses `dart:convert`.
String encodeSegmentSkipConfig(Map<SegmentType, SegmentSkipMode> config) {
  final map = <String, String>{};
  for (final entry in config.entries) {
    map[entry.key.name] = entry.value.name;
  }
  return jsonEncode(map);
}

/// Decodes a JSON string back to a per-type skip config map.
///
/// Returns [defaultSegmentSkipConfig] for null or empty input.
/// Lives in data layer because it uses `dart:convert`.
Map<SegmentType, SegmentSkipMode> decodeSegmentSkipConfig(String? json) {
  if (json == null || json.isEmpty) {
    return Map.of(defaultSegmentSkipConfig);
  }
  try {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    final result = Map.of(defaultSegmentSkipConfig);
    for (final entry in raw.entries) {
      final type = SegmentType.values.where((t) => t.name == entry.key);
      final mode = SegmentSkipMode.values.where((m) => m.name == entry.value);
      if (type.isNotEmpty && mode.isNotEmpty) {
        result[type.first] = mode.first;
      }
    }
    return result;
  } catch (_) {
    return Map.of(defaultSegmentSkipConfig);
  }
}
