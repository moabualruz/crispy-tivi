import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/settings_notifier.dart';
import '../../../core/data/cache_service.dart';
import '../../../core/domain/entities/playlist_source.dart';
import '../../profiles/data/profile_service.dart';

/// Service for two-way Stalker portal favorites synchronization.
///
/// **Pull (server -> local):** After a Stalker sync completes,
/// [syncFromServer] fetches server-side favorites and marks matching
/// channels as favorites in the local DB.
///
/// **Push (local -> server):** When the user toggles a favorite
/// locally on a Stalker channel, [pushFavoriteToServer] sends the
/// change to the Stalker portal so the two stay in sync.
class StalkerFavoritesService {
  StalkerFavoritesService(this._ref);

  final Ref _ref;

  /// Fetches server-side Stalker favorites and syncs them to local DB.
  ///
  /// Called after Stalker source sync completes. Iterates all Stalker
  /// sources and fetches their favorite IDs for live channels ("itv").
  ///
  /// Server favorites are added to the local favorites list. Existing
  /// local favorites for non-Stalker sources are unaffected.
  Future<void> syncFromServer() async {
    final settings = _ref.read(settingsNotifierProvider).value;
    if (settings == null) return;

    final profileState = _ref.read(profileServiceProvider);
    final activeProfileId = profileState.value?.activeProfileId;
    if (activeProfileId == null) return;

    final backend = _ref.read(crispyBackendProvider);
    final cache = _ref.read(cacheServiceProvider);

    final stalkerSources =
        settings.sources
            .where((s) => s.type == PlaylistSourceType.stalkerPortal)
            .toList();

    for (final source in stalkerSources) {
      try {
        // Fetch live channel favorites from server.
        final json = await backend.getStalkerFavorites(
          baseUrl: source.url,
          macAddress: source.macAddress ?? '',
          streamType: 'itv',
          acceptInvalidCerts: source.acceptSelfSigned,
        );

        final ids = _parseFavoriteIds(json, source.id);

        // Mark fetched IDs as favorites in local DB.
        for (final id in ids) {
          await cache.addFavorite(activeProfileId, id);
        }

        if (ids.isNotEmpty) {
          debugPrint(
            'StalkerFavorites: synced ${ids.length} favorites '
            'from ${source.name}',
          );
        }
      } catch (e) {
        debugPrint(
          'StalkerFavorites: failed to sync from '
          '${source.name}: $e',
        );
      }
    }
  }

  /// Pushes a local favorite toggle to the Stalker portal.
  ///
  /// [channelId] is the local channel ID (e.g., `"stk_42"`).
  /// [source] is the Stalker portal source that owns the channel.
  /// [remove] is `true` when removing a favorite, `false` when adding.
  Future<void> pushFavoriteToServer({
    required String channelId,
    required PlaylistSource source,
    required bool remove,
  }) async {
    if (source.type != PlaylistSourceType.stalkerPortal) return;

    // Extract the Stalker-native ID from the prefixed channel ID.
    final nativeId = channelId.replaceFirst(RegExp(r'^stk_'), '');

    try {
      final backend = _ref.read(crispyBackendProvider);
      await backend.setStalkerFavorite(
        baseUrl: source.url,
        macAddress: source.macAddress ?? '',
        favId: nativeId,
        streamType: 'itv',
        remove: remove,
        acceptInvalidCerts: source.acceptSelfSigned,
      );
      debugPrint(
        'StalkerFavorites: ${remove ? "removed" : "added"} '
        'favorite $channelId on ${source.name}',
      );
    } catch (e) {
      debugPrint(
        'StalkerFavorites: failed to push favorite '
        '$channelId to ${source.name}: $e',
      );
    }
  }

  /// Parses the JSON array of favorite ID strings from the
  /// Rust response and converts them to local channel IDs.
  ///
  /// Server returns raw numeric IDs; we prefix with `stk_` to
  /// match the local channel ID format.
  List<String> _parseFavoriteIds(String json, String sourceId) {
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => 'stk_${e.toString()}').toList();
    } catch (e) {
      debugPrint('StalkerFavorites: parse error: $e');
      return const [];
    }
  }
}

/// Global provider for [StalkerFavoritesService].
final stalkerFavoritesServiceProvider = Provider<StalkerFavoritesService>(
  (ref) => StalkerFavoritesService(ref),
);
