import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/screens/media_server_series_screen.dart';
import '../providers/jellyfin_providers.dart';

/// [JF-FE-12] Jellyfin series navigation screen.
///
/// Thin wrapper around [MediaServerSeriesScreen] that wires Jellyfin-specific
/// providers. All UI logic lives in the shared screen.
///
/// Route: `/jellyfin/series/:seriesId?title=...`
class JellyfinSeriesScreen extends ConsumerWidget {
  const JellyfinSeriesScreen({
    required this.seriesId,
    required this.title,
    super.key,
  });

  /// The Jellyfin series item ID.
  final String seriesId;

  /// Display title shown in the AppBar.
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaServerSeriesScreen(
      seriesId: seriesId,
      title: title,
      scaffoldKey: TestKeys.jellyfinSeriesScreen,
      serverType: MediaServerType.jellyfin,
      heroTagPrefix: 'jellyfin_series_',
      seasonsProvider: (ref, id) => ref.watch(jellyfinSeasonsProvider(id)),
      episodesProvider:
          (ref, seriesId, seasonId) =>
              ref.watch(jellyfinEpisodesProvider((seriesId, seasonId))),
      streamUrlProvider:
          (ref, itemId) => ref.read(jellyfinStreamUrlProvider(itemId).future),
    );
  }
}
