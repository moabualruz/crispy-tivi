import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/screens/media_server_series_screen.dart';
import '../providers/emby_providers.dart';

/// [EB-FE-11] Emby series navigation screen.
///
/// Thin wrapper around [MediaServerSeriesScreen] that wires Emby-specific
/// providers. All UI logic lives in the shared screen.
///
/// Route: `/emby/series/:seriesId?title=...`
class EmbySeriesScreen extends ConsumerWidget {
  const EmbySeriesScreen({
    required this.seriesId,
    required this.title,
    super.key,
  });

  /// The Emby series item ID.
  final String seriesId;

  /// Display title shown in the AppBar.
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaServerSeriesScreen(
      seriesId: seriesId,
      title: title,
      scaffoldKey: TestKeys.embySeriesScreen,
      serverType: MediaServerType.emby,
      heroTagPrefix: 'emby_series_',
      seasonsProvider: (ref, id) => ref.watch(embySeasonsProvider(id)),
      episodesProvider:
          (ref, seriesId, seasonId) =>
              ref.watch(embyEpisodesProvider((seriesId, seasonId))),
      streamUrlProvider:
          (ref, itemId) => ref.read(embyStreamUrlProvider(itemId).future),
    );
  }
}
