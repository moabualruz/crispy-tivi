import '../../domain/entities/channel.dart';

/// Data model for [Channel].
///
/// Separate from the domain entity to keep infrastructure
/// concerns (mutable fields) out of the domain layer.
/// Currently backed by in-memory storage; ready for future
/// persistence migration (Hive, Drift, etc.).
class ChannelModel {
  ChannelModel({
    this.obxId = 0,
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
    this.sourceId,
    this.hasCatchup = false,
    this.catchupDays = 0,
    this.catchupType,
    this.catchupSource,
    this.isSport = false,
  });

  int obxId;

  /// Domain ID (hash of streamUrl or Xtream stream ID).
  String id;

  String name;
  String streamUrl;
  int? number;

  String? group;

  String? logoUrl;

  String? tvgId;

  String? tvgName;
  bool isFavorite;
  String? userAgent;

  /// Which playlist source this channel belongs to.
  String? sourceId;

  /// Whether this channel supports catch-up/archive playback.
  bool hasCatchup;

  /// Number of days of catch-up archive available.
  int catchupDays;

  /// Catch-up type for M3U sources (flussonic, shift, append).
  String? catchupType;

  /// Catch-up URL template for M3U sources.
  String? catchupSource;

  /// Whether this channel primarily broadcasts sports content.
  bool isSport;

  // ── Domain Mappers ──────────────────────────────────────

  /// Converts this model to a domain [Channel].
  Channel toDomain() {
    return Channel(
      id: id,
      name: name,
      streamUrl: streamUrl,
      number: number,
      group: group,
      logoUrl: logoUrl,
      tvgId: tvgId,
      tvgName: tvgName,
      isFavorite: isFavorite,
      userAgent: userAgent,
      hasCatchup: hasCatchup,
      catchupDays: catchupDays,
      catchupType: catchupType,
      catchupSource: catchupSource,
      sourceId: sourceId,
      isSport: isSport,
    );
  }

  /// Creates a model from a domain [Channel].
  static ChannelModel fromDomain(Channel channel, {String? sourceId}) {
    return ChannelModel(
      id: channel.id,
      name: channel.name,
      streamUrl: channel.streamUrl,
      number: channel.number,
      group: channel.group,
      logoUrl: channel.logoUrl,
      tvgId: channel.tvgId,
      tvgName: channel.tvgName,
      isFavorite: channel.isFavorite,
      userAgent: channel.userAgent,
      sourceId: sourceId,
      hasCatchup: channel.hasCatchup,
      catchupDays: channel.catchupDays,
      catchupType: channel.catchupType,
      catchupSource: channel.catchupSource,
      isSport: channel.isSport,
    );
  }
}
