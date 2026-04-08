import 'dart:convert';

/// Typed Dart model for Rust `DataChangeEvent` variants.
///
/// Deserialized from JSON strings pushed by
/// `CrispyBackend.dataEvents`. Uses Dart 3 sealed class
/// for exhaustive pattern matching.
sealed class DataChangeEvent {
  const DataChangeEvent();

  /// Parse a JSON string from the event stream into a
  /// typed [DataChangeEvent]. Returns [UnknownEvent] for
  /// unrecognized types (forward-compatible).
  factory DataChangeEvent.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final type = map['type'] as String? ?? '';
    return switch (type) {
      'ChannelsUpdated' => ChannelsUpdated(
        sourceId: map['source_id'] as String,
      ),
      'CategoriesUpdated' => CategoriesUpdated(
        sourceId: map['source_id'] as String,
      ),
      'ChannelOrderChanged' => const ChannelOrderChanged(),
      'EpgUpdated' => EpgUpdated(sourceId: map['source_id'] as String),
      'WatchHistoryUpdated' => WatchHistoryUpdated(
        channelId: map['channel_id'] as String,
      ),
      'WatchHistoryCleared' => const WatchHistoryCleared(),
      'FavoriteToggled' => FavoriteToggled(
        itemId: map['item_id'] as String,
        isFavorite: map['is_favorite'] as bool,
      ),
      'FavoriteCategoryToggled' => FavoriteCategoryToggled(
        categoryType: map['category_type'] as String,
        categoryName: map['category_name'] as String,
      ),
      'VodUpdated' => VodUpdated(sourceId: map['source_id'] as String),
      'VodFavoriteToggled' => VodFavoriteToggled(
        vodId: map['vod_id'] as String,
        isFavorite: map['is_favorite'] as bool,
      ),
      'VodWatchProgressUpdated' => VodWatchProgressUpdated(
        vodId: map['vod_id'] as String,
      ),
      'RecordingChanged' => RecordingChanged(
        recordingId: map['recording_id'] as String,
      ),
      'ProfileChanged' => ProfileChanged(
        profileId: map['profile_id'] as String,
      ),
      'SettingsUpdated' => SettingsUpdated(key: map['key'] as String),
      'SavedLayoutChanged' => const SavedLayoutChanged(),
      'SearchHistoryChanged' => const SearchHistoryChanged(),
      'ReminderChanged' => const ReminderChanged(),
      'CloudSyncCompleted' => const CloudSyncCompleted(),
      'BulkDataRefresh' => const BulkDataRefresh(),
      _ => UnknownEvent(type),
    };
  }
}

// ── Channels / Playlists ──────────────────────────────

class ChannelsUpdated extends DataChangeEvent {
  final String sourceId;
  const ChannelsUpdated({required this.sourceId});
}

class CategoriesUpdated extends DataChangeEvent {
  final String sourceId;
  const CategoriesUpdated({required this.sourceId});
}

class ChannelOrderChanged extends DataChangeEvent {
  const ChannelOrderChanged();
}

// ── EPG ───────────────────────────────────────────────

class EpgUpdated extends DataChangeEvent {
  final String sourceId;
  const EpgUpdated({required this.sourceId});
}

// ── Watch History ─────────────────────────────────────

class WatchHistoryUpdated extends DataChangeEvent {
  final String channelId;
  const WatchHistoryUpdated({required this.channelId});
}

class WatchHistoryCleared extends DataChangeEvent {
  const WatchHistoryCleared();
}

// ── Favorites ─────────────────────────────────────────

class FavoriteToggled extends DataChangeEvent {
  final String itemId;
  final bool isFavorite;
  const FavoriteToggled({required this.itemId, required this.isFavorite});
}

class FavoriteCategoryToggled extends DataChangeEvent {
  final String categoryType;
  final String categoryName;
  const FavoriteCategoryToggled({
    required this.categoryType,
    required this.categoryName,
  });
}

// ── VOD ───────────────────────────────────────────────

class VodUpdated extends DataChangeEvent {
  final String sourceId;
  const VodUpdated({required this.sourceId});
}

class VodFavoriteToggled extends DataChangeEvent {
  final String vodId;
  final bool isFavorite;
  const VodFavoriteToggled({required this.vodId, required this.isFavorite});
}

class VodWatchProgressUpdated extends DataChangeEvent {
  final String vodId;
  const VodWatchProgressUpdated({required this.vodId});
}

// ── Recordings / DVR ──────────────────────────────────

class RecordingChanged extends DataChangeEvent {
  final String recordingId;
  const RecordingChanged({required this.recordingId});
}

// ── Profiles ──────────────────────────────────────────

class ProfileChanged extends DataChangeEvent {
  final String profileId;
  const ProfileChanged({required this.profileId});
}

// ── Settings ──────────────────────────────────────────

class SettingsUpdated extends DataChangeEvent {
  final String key;
  const SettingsUpdated({required this.key});
}

// ── Misc UI data ──────────────────────────────────────

class SavedLayoutChanged extends DataChangeEvent {
  const SavedLayoutChanged();
}

class SearchHistoryChanged extends DataChangeEvent {
  const SearchHistoryChanged();
}

class ReminderChanged extends DataChangeEvent {
  const ReminderChanged();
}

// ── Bulk ──────────────────────────────────────────────

class CloudSyncCompleted extends DataChangeEvent {
  const CloudSyncCompleted();
}

class BulkDataRefresh extends DataChangeEvent {
  const BulkDataRefresh();
}

// ── Forward-compatibility ─────────────────────────────

class UnknownEvent extends DataChangeEvent {
  final String type;
  const UnknownEvent(this.type);
}
