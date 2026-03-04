/// Represents a group of duplicate channels sharing the same stream URL.
class DuplicateGroup {
  const DuplicateGroup({
    required this.streamUrl,
    required this.channelIds,
    this.preferredId,
  });

  /// The normalized stream URL shared by all channels in this group.
  final String streamUrl;

  /// IDs of all channels sharing this stream URL.
  final List<String> channelIds;

  /// User-selected preferred channel ID (defaults to first in list).
  final String? preferredId;

  /// Number of channels in this group.
  int get count => channelIds.length;

  /// Whether this group has actual duplicates (more than one channel).
  bool get hasDuplicates => count > 1;

  /// The preferred channel ID, or first if not set.
  String get preferred => preferredId ?? channelIds.first;

  /// All channel IDs except the preferred one (the actual duplicates).
  List<String> get duplicateIds =>
      channelIds.where((id) => id != preferred).toList();

  DuplicateGroup copyWith({
    String? streamUrl,
    List<String>? channelIds,
    String? preferredId,
  }) {
    return DuplicateGroup(
      streamUrl: streamUrl ?? this.streamUrl,
      channelIds: channelIds ?? this.channelIds,
      preferredId: preferredId ?? this.preferredId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DuplicateGroup) return false;
    if (streamUrl != other.streamUrl) return false;
    if (channelIds.length != other.channelIds.length) return false;
    for (var i = 0; i < channelIds.length; i++) {
      if (channelIds[i] != other.channelIds[i]) return false;
    }
    return preferredId == other.preferredId;
  }

  @override
  int get hashCode =>
      Object.hash(streamUrl, Object.hashAll(channelIds), preferredId);

  @override
  String toString() =>
      'DuplicateGroup(url: $streamUrl, count: $count, ids: $channelIds)';
}
