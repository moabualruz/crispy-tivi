import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../providers/vod_service_providers.dart';
import '../../../../core/network/http_service.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../../domain/entities/vod_item.dart';

/// Result of fetching series episodes from the
/// Xtream API.
class EpisodeFetchResult {
  const EpisodeFetchResult({required this.episodes, required this.seasons});

  final List<VodItem> episodes;
  final List<int> seasons;
}

/// Fetches episodes for a series from the Xtream
/// `get_series_info` endpoint.
///
/// Accepts both [Ref] (from a provider) and [WidgetRef]
/// (from a widget) — [WidgetRef] is a subtype of [Ref].
///
/// Throws on failure (caller should catch and show
/// error state).
Future<EpisodeFetchResult> fetchSeriesEpisodes(
  Ref ref,
  String seriesId, {
  String? sourceId,
}) async {
  final settings = ref.read(settingsNotifierProvider).value;
  if (settings == null) {
    throw Exception('Settings not loaded');
  }

  final xtreamSources = settings.sources.where(
    (s) => s.type == PlaylistSourceType.xtream,
  );

  // Prefer the source that owns this series; fall back to first.
  final xtreamSource =
      (sourceId != null
          ? xtreamSources.where((s) => s.id == sourceId).firstOrNull
          : null) ??
      xtreamSources.firstOrNull;
  if (xtreamSource == null) {
    throw Exception('No Xtream source configured');
  }

  final numericId = seriesId.replaceFirst('series_', '');
  final uri = Uri.parse(xtreamSource.url);
  final baseUrl =
      '${uri.scheme}://${uri.host}'
      '${uri.hasPort ? ":${uri.port}" : ""}';
  final url =
      '$baseUrl/player_api.php?'
      'username=${xtreamSource.username}&'
      'password=${xtreamSource.password}&'
      'action=get_series_info&'
      'series_id=$numericId';

  final http = ref.read(httpServiceProvider);
  final data = await http.getJson(url);
  if (data is! Map<String, dynamic>) {
    throw Exception('Invalid series info response');
  }

  final backend = ref.read(crispyBackendProvider);
  final episodes = await VodParser.parseEpisodes(
    data,
    backend,
    baseUrl: baseUrl,
    username: xtreamSource.username ?? '',
    password: xtreamSource.password ?? '',
    seriesId: numericId,
  );

  final seasons =
      episodes.map((e) => e.seasonNumber).whereType<int>().toSet().toList()
        ..sort();

  return EpisodeFetchResult(episodes: episodes, seasons: seasons);
}
