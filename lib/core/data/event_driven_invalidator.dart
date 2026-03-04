import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/settings_notifier.dart';
import '../../features/dvr/data/dvr_service.dart';
import '../../features/epg/presentation/providers/epg_providers.dart';
import '../../features/favorites/presentation/providers/favorites_controller.dart';
import '../../features/home/presentation/providers/home_providers.dart';
import '../../features/iptv/presentation/providers/channel_providers.dart';
import '../../features/multiview/presentation/providers/multiview_providers.dart';
import '../../features/player/data/watch_history_service.dart';
import '../../features/profiles/data/profile_service.dart';
import '../../features/profiles/data/source_access_service.dart';
import '../../features/vod/presentation/providers/favorite_categories_provider.dart';
import '../../features/vod/presentation/providers/vod_favorites_provider.dart';
import '../../features/vod/presentation/providers/vod_providers.dart';
import 'data_change_event.dart';
import 'event_bus_provider.dart';

/// Watches the [eventBusProvider] and invalidates the
/// correct Riverpod providers based on event type.
///
/// Must be initialized at app startup via
/// `ref.watch(eventDrivenInvalidatorProvider)` in the
/// root widget. One central listener, targeted dispatch.
///
/// Events are buffered for 50 ms and deduplicated by type
/// before being processed, preventing redundant invalidations
/// during rapid bursts. [BulkDataRefresh] and
/// [CloudSyncCompleted] bypass the debounce and fire
/// immediately.
final eventDrivenInvalidatorProvider = Provider<void>((ref) {
  Timer? debounceTimer;
  final pendingEvents = <DataChangeEvent>[];

  ref.listen(eventBusProvider, (prev, next) {
    final event = next.value;
    if (event == null) return;

    // Bulk events bypass debounce — immediate full refresh.
    if (event is BulkDataRefresh || event is CloudSyncCompleted) {
      debounceTimer?.cancel();
      pendingEvents.clear();
      _handleEvent(ref, event);
      return;
    }

    pendingEvents.add(event);
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _processPendingEvents(ref, pendingEvents);
    });
  });

  ref.onDispose(() {
    debounceTimer?.cancel();
  });
});

/// Process buffered events, deduplicating by type to
/// avoid redundant invalidations.
void _processPendingEvents(Ref ref, List<DataChangeEvent> events) {
  // Deduplicate: keep last event per runtimeType.
  final seen = <Type, DataChangeEvent>{};
  for (final e in events) {
    seen[e.runtimeType] = e;
  }
  events.clear();

  for (final event in seen.values) {
    _handleEvent(ref, event);
  }
}

void _handleEvent(Ref ref, DataChangeEvent event) {
  if (kDebugMode) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    debugPrint('[EventInvalidator] $ts ${_eventDescription(event)}');
  }

  switch (event) {
    // ── Channels / Playlists ─────────────────────
    case ChannelsUpdated():
      _safeRefresh(
        ref.read(channelListProvider.notifier).refreshFromBackend,
        'ChannelsUpdated/channelList',
      );
      ref.invalidate(channelGroupsProvider);

    case CategoriesUpdated():
      _safeRefresh(
        ref.read(channelListProvider.notifier).refreshFromBackend,
        'CategoriesUpdated/channelList',
      );

    case ChannelOrderChanged():
      _safeRefresh(
        ref.read(channelListProvider.notifier).refreshFromBackend,
        'ChannelOrderChanged/channelList',
      );

    // ── EPG ──────────────────────────────────────
    case EpgUpdated():
      _safeRefresh(
        ref.read(epgProvider.notifier).refreshEntries,
        'EpgUpdated/epg',
      );

    // ── Watch History ────────────────────────────
    case WatchHistoryUpdated():
      ref.invalidate(continueWatchingMoviesProvider);
      ref.invalidate(continueWatchingSeriesProvider);
      ref.invalidate(crossDeviceWatchingProvider);
      ref.invalidate(recentChannelsProvider);

    case WatchHistoryCleared():
      ref.invalidate(continueWatchingMoviesProvider);
      ref.invalidate(continueWatchingSeriesProvider);
      ref.invalidate(crossDeviceWatchingProvider);
      ref.invalidate(recentChannelsProvider);

    // ── Favorites ────────────────────────────────
    case FavoriteToggled():
      ref.invalidate(favoritesControllerProvider);
      ref.invalidate(favoriteChannelsProvider);

    case FavoriteCategoryToggled(:final categoryType):
      ref.invalidate(favoriteCategoriesProvider(categoryType));

    // ── VOD ──────────────────────────────────────
    case VodUpdated():
      _safeRefresh(
        ref.read(vodProvider.notifier).refreshFromBackend,
        'VodUpdated/vod',
      );

    case VodFavoriteToggled():
      ref.invalidate(vodFavoritesProvider);

    case VodWatchProgressUpdated():
      ref.invalidate(continueWatchingMoviesProvider);
      ref.invalidate(continueWatchingSeriesProvider);

    // ── Recordings / DVR ─────────────────────────
    case RecordingChanged():
      ref.invalidate(dvrServiceProvider);

    // ── Profiles ─────────────────────────────────
    case ProfileChanged():
      ref.invalidate(profileServiceProvider);
      ref.invalidate(accessibleSourcesProvider);

    // ── Settings ─────────────────────────────────
    case SettingsUpdated():
      ref.invalidate(settingsNotifierProvider);

    // ── Misc UI data ─────────────────────────────
    case SavedLayoutChanged():
      ref.invalidate(savedLayoutsProvider);

    case SearchHistoryChanged():
      // Search history UI reads on-demand; no
      // cached provider to invalidate.
      break;

    case ReminderChanged():
      // Reminders are timer-based, not cached in
      // a provider. DVR service handles scheduling.
      ref.invalidate(dvrServiceProvider);

    // ── Bulk ─────────────────────────────────────
    case CloudSyncCompleted():
      _invalidateAllDataProviders(ref);

    case BulkDataRefresh():
      _invalidateAllDataProviders(ref);

    // ── Forward-compatibility ────────────────────
    case UnknownEvent(:final type):
      debugPrint('EventDrivenInvalidator: unknown event type: $type');
  }
}

/// Fire [refresh] as a detached Future, logging any
/// error that surfaces instead of swallowing it silently.
void _safeRefresh(Future<void> Function() refresh, String label) {
  unawaited(
    refresh().catchError((Object error, StackTrace stack) {
      debugPrint('[EventInvalidator] refresh error ($label): $error\n$stack');
    }),
  );
}

/// Human-readable description for debug logging.
String _eventDescription(DataChangeEvent event) {
  return switch (event) {
    ChannelsUpdated(:final sourceId) => 'ChannelsUpdated(source: $sourceId)',
    CategoriesUpdated(:final sourceId) =>
      'CategoriesUpdated(source: $sourceId)',
    ChannelOrderChanged() => 'ChannelOrderChanged',
    EpgUpdated(:final sourceId) => 'EpgUpdated(source: $sourceId)',
    WatchHistoryUpdated(:final channelId) =>
      'WatchHistoryUpdated(channel: $channelId)',
    WatchHistoryCleared() => 'WatchHistoryCleared',
    FavoriteToggled(:final itemId, :final isFavorite) =>
      'FavoriteToggled(item: $itemId, fav: $isFavorite)',
    FavoriteCategoryToggled(:final categoryType, :final categoryName) =>
      'FavoriteCategoryToggled($categoryType/$categoryName)',
    VodUpdated(:final sourceId) => 'VodUpdated(source: $sourceId)',
    VodFavoriteToggled(:final vodId, :final isFavorite) =>
      'VodFavoriteToggled(vod: $vodId, fav: $isFavorite)',
    VodWatchProgressUpdated(:final vodId) =>
      'VodWatchProgressUpdated(vod: $vodId)',
    RecordingChanged(:final recordingId) =>
      'RecordingChanged(rec: $recordingId)',
    ProfileChanged(:final profileId) => 'ProfileChanged(profile: $profileId)',
    SettingsUpdated(:final key) => 'SettingsUpdated(key: $key)',
    SavedLayoutChanged() => 'SavedLayoutChanged',
    SearchHistoryChanged() => 'SearchHistoryChanged',
    ReminderChanged() => 'ReminderChanged',
    CloudSyncCompleted() => 'CloudSyncCompleted',
    BulkDataRefresh() => 'BulkDataRefresh',
    UnknownEvent(:final type) => 'Unknown($type)',
  };
}

/// Invalidate all major data providers.
///
/// Used for bulk operations (cloud sync, full refresh).
void _invalidateAllDataProviders(Ref ref) {
  // Channels — refresh from backend (NotifierProvider).
  _safeRefresh(
    ref.read(channelListProvider.notifier).refreshFromBackend,
    'BulkRefresh/channelList',
  );
  ref.invalidate(channelGroupsProvider);

  // EPG — refresh entries for current window (NotifierProvider).
  _safeRefresh(
    ref.read(epgProvider.notifier).refreshEntries,
    'BulkRefresh/epg',
  );

  // Watch history
  ref.invalidate(continueWatchingMoviesProvider);
  ref.invalidate(continueWatchingSeriesProvider);
  ref.invalidate(crossDeviceWatchingProvider);
  ref.invalidate(recentChannelsProvider);

  // Favorites
  ref.invalidate(favoritesControllerProvider);
  ref.invalidate(favoriteChannelsProvider);

  // VOD — refresh from backend (NotifierProvider).
  _safeRefresh(
    ref.read(vodProvider.notifier).refreshFromBackend,
    'BulkRefresh/vod',
  );
  ref.invalidate(vodFavoritesProvider);

  // DVR
  ref.invalidate(dvrServiceProvider);

  // Profiles
  ref.invalidate(profileServiceProvider);
  ref.invalidate(accessibleSourcesProvider);

  // Settings
  ref.invalidate(settingsNotifierProvider);

  // Layouts
  ref.invalidate(savedLayoutsProvider);
}
