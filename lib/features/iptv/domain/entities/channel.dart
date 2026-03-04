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
    this.isSport = false,
  });

  /// Unique identifier (hash of streamUrl or Xtream stream ID).
  final String id;

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

  /// Flag to identify if a channel primarily broadcasts sports content.
  final bool isSport;

  /// Creates a copy with updated fields.
  Channel copyWith({
    String? id,
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
    bool? isSport,
  }) {
    return Channel(
      id: id ?? this.id,
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
      isSport: isSport ?? this.isSport,
    );
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
