import '../../../../core/domain/entities/playlist_source.dart';
import '../../data/sync_report_codec.dart';
import 'media_server_sync.dart';
import 'iptv_service_providers.dart';

export '../../data/sync_report_codec.dart' show SyncReport;

/// Default sync interval in hours.
const kDefaultSyncIntervalHours = 24;

/// Result of partitioning sources into stale vs fresh.
///
/// [stale] — sources that need a network sync.
/// [nextSync] — time until the freshest source expires, or
/// `null` when all sources are stale.
typedef PartitionResult = ({List<PlaylistSource> stale, Duration? nextSync});

/// Partitions [sources] into those that need syncing and
/// those that are still fresh.
///
/// A source is stale when it has no recorded [lastSyncTimes]
/// entry, or when the elapsed time since its last sync is
/// at least [interval].  For fresh sources the remaining
/// time until expiry is tracked and the smallest value is
/// returned as [nextSync].
///
/// All comparisons are done against the caller-supplied
/// [now] so the function is deterministic and testable
/// without side effects.
PartitionResult partitionStaleSources(
  List<PlaylistSource> sources,
  Map<String, DateTime> lastSyncTimes,
  Duration interval,
  DateTime now,
) {
  final stale = <PlaylistSource>[];
  Duration? nextSync;

  for (final source in sources) {
    final lastSync = lastSyncTimes[source.id];
    if (lastSync == null) {
      stale.add(source);
      continue;
    }
    final age = now.difference(lastSync);
    if (age >= interval) {
      stale.add(source);
    } else {
      final remaining = interval - age;
      if (nextSync == null || remaining < nextSync) {
        nextSync = remaining;
      }
    }
  }

  return (stale: stale, nextSync: nextSync);
}

/// Dispatches a sync call to the appropriate backend
/// method based on [source.type].
///
/// IPTV sources (M3U, Xtream, Stalker) sync via Rust.
/// Media server sources (Plex, Emby, Jellyfin) sync
/// via Dart HTTP clients into the same Rust DB.
Future<SyncReport> syncSourceViaRust(
  CrispyBackend backend,
  PlaylistSource source,
  MediaServerSyncService mediaServerSync,
  bool enrichVod,
) async {
  // Media server sources sync via Dart HTTP clients.
  if (source.type == PlaylistSourceType.plex ||
      source.type == PlaylistSourceType.emby ||
      source.type == PlaylistSourceType.jellyfin) {
    return mediaServerSync.syncSource(source);
  }

  // IPTV sources sync via Rust.
  final json = switch (source.type) {
    PlaylistSourceType.m3u => await backend.syncM3uSource(
      url: source.url,
      sourceId: source.id,
      acceptInvalidCerts: source.acceptSelfSigned,
    ),
    PlaylistSourceType.xtream => await backend.syncXtreamSource(
      baseUrl: source.url,
      username: source.username ?? '',
      password: source.password ?? '',
      sourceId: source.id,
      acceptInvalidCerts: source.acceptSelfSigned,
      enrichVodOnSync: enrichVod,
    ),
    PlaylistSourceType.stalkerPortal => await backend.syncStalkerSource(
      baseUrl: source.url,
      macAddress: source.macAddress ?? '',
      sourceId: source.id,
      acceptInvalidCerts: source.acceptSelfSigned,
    ),
    _ =>
      '{"channels_count":0,"channel_groups":[],'
          '"vod_count":0,"vod_categories":[],"epg_url":null}',
  };
  return decodeSyncReport(json);
}
