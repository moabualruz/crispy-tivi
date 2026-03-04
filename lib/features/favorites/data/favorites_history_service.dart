import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../iptv/domain/entities/channel.dart';

/// Watch history and favorites service.
///
/// Manages cross-playlist favorites, recently watched history,
/// continue watching positions, and last-viewed channel.
class FavoritesHistoryService extends Notifier<FavoritesHistoryState> {
  @override
  FavoritesHistoryState build() => const FavoritesHistoryState();

  /// Adds a channel to recently watched.
  ///
  /// FE-FAV-05: Recording is skipped when the user has paused
  /// history recording via [settingsNotifierProvider].
  void addToHistory(Channel channel) {
    // Check if history recording is paused.
    final settingsAsync = ref.read(settingsNotifierProvider);
    final paused = settingsAsync.value?.historyRecordingPaused ?? false;
    if (paused) return;

    final updated =
        [
          channel,
          ...state.recentlyWatched.where((c) => c.id != channel.id),
        ].take(50).toList();
    state = state.copyWith(recentlyWatched: updated, lastChannelId: channel.id);
  }

  /// Saves watch position for a VOD item.
  ///
  /// FE-FAV-05: Recording is skipped when history recording is
  /// paused unless this is an explicit mark-as-watched call
  /// (see [markAsWatched]).
  void saveWatchPosition(String itemId, Duration position, Duration total) {
    // Check if history recording is paused.
    final settingsAsync = ref.read(settingsNotifierProvider);
    final paused = settingsAsync.value?.historyRecordingPaused ?? false;
    if (paused) return;

    _writeWatchPosition(itemId, position, total);
  }

  /// FE-FAV-07: Marks a VOD item as fully watched by setting its
  /// position to 100% of the total duration.
  ///
  /// Always writes regardless of history-recording pause state —
  /// this is an intentional user action.
  void markAsWatched(String itemId) {
    final existing = state.watchPositions[itemId];
    final total = existing?.total ?? const Duration(hours: 1); // fallback 1 h
    _writeWatchPosition(itemId, total, total);
  }

  /// Internal helper that writes a [WatchPosition] unconditionally.
  void _writeWatchPosition(String itemId, Duration position, Duration total) {
    final updated = Map<String, WatchPosition>.from(state.watchPositions);
    updated[itemId] = WatchPosition(
      position: position,
      total: total,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(watchPositions: updated);
  }

  /// Gets watch position for a VOD item.
  WatchPosition? getWatchPosition(String itemId) {
    return state.watchPositions[itemId];
  }

  /// Clears all watch history.
  void clearHistory() {
    state = state.copyWith(recentlyWatched: [], watchPositions: {});
  }

  /// Removes a single item from history.
  void removeFromHistory(String channelId) {
    state = state.copyWith(
      recentlyWatched:
          state.recentlyWatched.where((c) => c.id != channelId).toList(),
    );
  }

  /// FE-FAV-06: Removes multiple channels from recently-watched history.
  void removeMultipleFromHistory(Set<String> channelIds) {
    state = state.copyWith(
      recentlyWatched:
          state.recentlyWatched
              .where((c) => !channelIds.contains(c.id))
              .toList(),
    );
  }
}

/// Watch position for continue-watching feature.
class WatchPosition {
  const WatchPosition({
    required this.position,
    required this.total,
    required this.timestamp,
  });

  final Duration position;
  final Duration total;
  final DateTime timestamp;

  double get progress {
    if (total.inSeconds == 0) return 0;
    return (position.inSeconds / total.inSeconds).clamp(0.0, 1.0);
  }

  bool get isCompleted => progress > 0.9;
}

class FavoritesHistoryState {
  const FavoritesHistoryState({
    this.recentlyWatched = const [],
    this.watchPositions = const {},
    this.lastChannelId,
  });

  final List<Channel> recentlyWatched;
  final Map<String, WatchPosition> watchPositions;
  final String? lastChannelId;

  /// Items with saved position that haven't been completed.
  List<String> get continueWatching {
    return watchPositions.entries
        .where((e) => !e.value.isCompleted)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) {
        final posA = watchPositions[a]!;
        final posB = watchPositions[b]!;
        return posB.timestamp.compareTo(posA.timestamp);
      });
  }

  FavoritesHistoryState copyWith({
    List<Channel>? recentlyWatched,
    Map<String, WatchPosition>? watchPositions,
    String? lastChannelId,
  }) {
    return FavoritesHistoryState(
      recentlyWatched: recentlyWatched ?? this.recentlyWatched,
      watchPositions: watchPositions ?? this.watchPositions,
      lastChannelId: lastChannelId ?? this.lastChannelId,
    );
  }
}

final favoritesHistoryProvider =
    NotifierProvider<FavoritesHistoryService, FavoritesHistoryState>(
      FavoritesHistoryService.new,
    );
