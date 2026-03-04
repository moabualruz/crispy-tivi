import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';

/// User rating for a VOD item: thumbs up, thumbs down, or none.
enum VodRating {
  /// No rating given.
  none,

  /// Thumbs up — the user liked this item.
  up,

  /// Thumbs down — the user disliked this item.
  down;

  /// Cycles through none → up → down → none.
  VodRating get next => switch (this) {
    VodRating.none => VodRating.up,
    VodRating.up => VodRating.down,
    VodRating.down => VodRating.none,
  };

  /// Serialises to a settings string.
  String toSettingValue() => name;

  /// Deserialises from a settings string; unknown values → [none].
  static VodRating fromSettingValue(String? value) => switch (value) {
    'up' => VodRating.up,
    'down' => VodRating.down,
    _ => VodRating.none,
  };
}

/// Settings key prefix for VOD user ratings.
const _kVodRatingKeyPrefix = 'vod_rating_';

/// Manages the user's thumbs up/down rating for a single VOD item.
///
/// State is loaded lazily from [CacheService.getSetting] and
/// persisted on every toggle via [CacheService.setSetting] /
/// [CacheService.removeSetting].
///
/// The rating cycles: none → up → down → none on each [toggle] call.
class VodRatingNotifier extends AsyncNotifier<VodRating> {
  VodRatingNotifier(this.itemId);

  /// The VOD item ID this notifier manages.
  final String itemId;

  String get _settingKey => '$_kVodRatingKeyPrefix$itemId';

  @override
  Future<VodRating> build() async {
    final cache = ref.watch(cacheServiceProvider);
    final value = await cache.getSetting(_settingKey);
    return VodRating.fromSettingValue(value);
  }

  /// Cycles the rating to the next state and persists it.
  Future<void> toggle() async {
    final current = state.value ?? VodRating.none;
    final next = current.next;
    final cache = ref.read(cacheServiceProvider);

    if (next == VodRating.none) {
      await cache.removeSetting(_settingKey);
    } else {
      await cache.setSetting(_settingKey, next.toSettingValue());
    }
    state = AsyncData(next);
  }
}

/// Provider for the user's rating of a specific VOD item.
///
/// Keyed by VOD item ID. Persists via [CacheService] settings.
final vodRatingProvider =
    AsyncNotifierProvider.family<VodRatingNotifier, VodRating, String>(
      (arg) => VodRatingNotifier(arg),
    );
