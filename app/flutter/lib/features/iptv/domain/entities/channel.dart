import 'package:meta/meta.dart';

/// A single IPTV channel parsed from an M3U playlist.
///
/// Domain entity — pure Dart, no infrastructure dependencies.
/// Corresponds to a `#EXTINF` entry in an M3U/M3U8 file.
@immutable
class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.nativeId,
    this.number,
    this.group,
    this.logoUrl,
    this.tvgId,
    this.tvgName,
    this.isFavorite = false,
    this.userAgent,
    this.hasCatchup = false,
    this.catchupDays = 0,
    this.catchupType,
    this.catchupSource,
    this.sourceId,
    this.resolution,
    this.addedAt,
    this.updatedAt,
    this.is247 = false,
    this.isSport = false,
    this.tvgUrl,
    this.streamPropertiesJson,
    this.vlcOptionsJson,
    this.timeshift,
    this.streamType,
    this.thumbnailUrl,
  });

  /// Unique identifier (hash of streamUrl or Xtream stream ID).
  final String id;

  /// Source-native ID (stream_id for Xtream, portal id for Stalker,
  /// url-hash for M3U). Matches the Rust `Channel.native_id` field.
  final String? nativeId;

  /// Display name from `#EXTINF` directive.
  final String name;

  /// Direct stream URL (HTTP/HTTPS).
  final String streamUrl;

  /// Optional channel number for ordering.
  final int? number;

  /// Group/category name (e.g., "Sports", "News").
  final String? group;

  /// Channel logo URL from `tvg-logo` attribute.
  final String? logoUrl;

  /// TVG ID for EPG mapping.
  final String? tvgId;

  /// TVG display name (may differ from [name]).
  final String? tvgName;

  /// Whether this channel is in the user's favorites.
  final bool isFavorite;

  /// Custom User-Agent header for this stream.
  final String? userAgent;

  /// Whether this channel supports catch-up/archive playback.
  final bool hasCatchup;

  /// Number of days of catch-up archive available.
  final int catchupDays;

  /// Catch-up type for M3U sources (flussonic, shift, append, etc).
  final String? catchupType;

  /// Catch-up URL template for M3U sources.
  /// Tokens: {utc_start}, {utc_end}, {duration}, {timestamp}
  final String? catchupSource;

  /// The playlist source ID this channel belongs to.
  /// Used for source access filtering in multi-user system.
  final String? sourceId;

  /// Stream resolution tag (e.g., 'SD', 'HD', 'FHD', '4K').
  /// Parsed from M3U metadata or inferred from channel name/URL.
  final String? resolution;

  /// Timestamp when this channel was first added.
  final DateTime? addedAt;

  /// Timestamp when this channel was last refreshed/updated.
  final DateTime? updatedAt;

  /// Whether this is a 24/7 loop channel.
  final bool is247;

  /// Flag to identify if a channel primarily broadcasts sports content.
  final bool isSport;

  /// Per-channel EPG URL (`tvg-url` M3U attribute).
  final String? tvgUrl;

  /// Kodi stream properties (KODIPROP) serialised as JSON.
  final String? streamPropertiesJson;

  /// VLC options (EXTVLCOPT) serialised as JSON.
  final String? vlcOptionsJson;

  /// Timeshift duration hint (`timeshift` M3U attribute).
  final String? timeshift;

  /// Xtream stream type (e.g. `"live"`).
  final String? streamType;

  /// Xtream channel thumbnail URL.
  final String? thumbnailUrl;

  /// Creates a copy with updated fields.
  Channel copyWith({
    String? id,
    String? nativeId,
    String? name,
    String? streamUrl,
    int? number,
    String? group,
    String? logoUrl,
    String? tvgId,
    String? tvgName,
    bool? isFavorite,
    String? userAgent,
    bool? hasCatchup,
    int? catchupDays,
    String? catchupType,
    String? catchupSource,
    String? sourceId,
    String? resolution,
    DateTime? addedAt,
    DateTime? updatedAt,
    bool? is247,
    bool? isSport,
    String? tvgUrl,
    String? streamPropertiesJson,
    String? vlcOptionsJson,
    String? timeshift,
    String? streamType,
    String? thumbnailUrl,
  }) {
    return Channel(
      id: id ?? this.id,
      nativeId: nativeId ?? this.nativeId,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      number: number ?? this.number,
      group: group ?? this.group,
      logoUrl: logoUrl ?? this.logoUrl,
      tvgId: tvgId ?? this.tvgId,
      tvgName: tvgName ?? this.tvgName,
      isFavorite: isFavorite ?? this.isFavorite,
      userAgent: userAgent ?? this.userAgent,
      hasCatchup: hasCatchup ?? this.hasCatchup,
      catchupDays: catchupDays ?? this.catchupDays,
      catchupType: catchupType ?? this.catchupType,
      catchupSource: catchupSource ?? this.catchupSource,
      sourceId: sourceId ?? this.sourceId,
      resolution: resolution ?? this.resolution,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      is247: is247 ?? this.is247,
      isSport: isSport ?? this.isSport,
      tvgUrl: tvgUrl ?? this.tvgUrl,
      streamPropertiesJson: streamPropertiesJson ?? this.streamPropertiesJson,
      vlcOptionsJson: vlcOptionsJson ?? this.vlcOptionsJson,
      timeshift: timeshift ?? this.timeshift,
      streamType: streamType ?? this.streamType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  // ── Domain behaviour ──────────────────────────────────────

  /// Whether this channel has a valid stream URL that can be played.
  bool get isPlayable => streamUrl.isNotEmpty;

  /// Whether this channel has EPG data mapped via TVG identifiers.
  bool get hasEpg =>
      (tvgId != null && tvgId!.isNotEmpty) ||
      (tvgName != null && tvgName!.isNotEmpty);

  /// Whether this channel is a radio station.
  ///
  /// Determined by the explicit [streamType] field or group/name hints.
  bool get isRadio {
    final type = streamType?.toLowerCase() ?? '';
    if (type == 'radio') return true;
    final grpHint = group?.toLowerCase() ?? '';
    final nameHint = name.toLowerCase();
    return grpHint.contains('radio') || nameHint.contains('radio');
  }

  /// Best display name — prefers [tvgName] when it is set and
  /// different from the raw [name], falling back to [name].
  String get displayName {
    if (tvgName != null && tvgName!.isNotEmpty && tvgName != name) {
      return tvgName!;
    }
    return name;
  }

  /// Whether this channel matches a search [query].
  ///
  /// Case-insensitive comparison against [displayName] and [group].
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return displayName.toLowerCase().contains(q) ||
        (group?.toLowerCase().contains(q) ?? false);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'Channel($name, group=$group)';
}
