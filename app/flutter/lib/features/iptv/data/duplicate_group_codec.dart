import 'dart:convert';

import '../domain/entities/duplicate_group.dart';

/// Encodes a list of [DuplicateGroup]s to the JSON string
/// expected by the Rust backend.
///
/// Lives in data layer because it uses `dart:convert`.
String encodeDuplicateGroups(List<DuplicateGroup> groups) {
  return jsonEncode(
    groups
        .map(
          (g) => {
            'stream_url': g.streamUrl,
            'channel_ids': g.channelIds,
            if (g.preferredId != null) 'preferred_id': g.preferredId,
          },
        )
        .toList(),
  );
}

/// Decodes a single [DuplicateGroup] from a JSON string
/// returned by the Rust backend.
///
/// Returns `null` for null or empty input.
DuplicateGroup? decodeDuplicateGroup(String? json) {
  if (json == null || json.isEmpty) return null;
  final m = jsonDecode(json) as Map<String, dynamic>;
  final streamUrl = m['stream_url'] as String? ?? '';
  final channelIds = (m['channel_ids'] as List<dynamic>?)?.cast<String>() ?? [];
  return DuplicateGroup(streamUrl: streamUrl, channelIds: channelIds);
}
