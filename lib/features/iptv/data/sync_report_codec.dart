import 'dart:convert';

/// Result of a Rust source sync operation.
class SyncReport {
  const SyncReport({
    this.channelsCount = 0,
    this.channelGroups = const [],
    this.vodCount = 0,
    this.vodCategories = const [],
    this.epgUrl,
  });

  final int channelsCount;
  final List<String> channelGroups;
  final int vodCount;
  final List<String> vodCategories;
  final String? epgUrl;

  /// Alias for [channelsCount] — kept for call-site compatibility.
  int get totalChannels => channelsCount;
}

/// Decodes a [SyncReport] from a JSON string returned by the Rust
/// backend sync methods.
///
/// Lives in data layer because it uses `dart:convert`.
SyncReport decodeSyncReport(String json) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  return SyncReport(
    channelsCount: map['channels_count'] as int? ?? 0,
    channelGroups:
        (map['channel_groups'] as List?)?.cast<String>() ?? const [],
    vodCount: map['vod_count'] as int? ?? 0,
    vodCategories:
        (map['vod_categories'] as List?)?.cast<String>() ?? const [],
    epgUrl: map['epg_url'] as String?,
  );
}
