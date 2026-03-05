import 'dart:async';
import 'dart:convert';
import 'dart:math' show exp;

import '../constants.dart';
import '../../features/vod/domain/utils/vod_utils.dart' show parseRating;
import 'crispy_backend.dart';
import 'dart_algorithm_fallbacks.dart';
import 'epg_time_utils.dart';
import 'xtream_url_builder.dart';

part 'memory_backend_channels.dart';
part 'memory_backend_vod.dart';
part 'memory_backend_epg.dart';
part 'memory_backend_dvr.dart';
part 'memory_backend_profiles.dart';
part 'memory_backend_settings.dart';
part 'memory_backend_parsers.dart';
part 'memory_backend_algo_core.dart';
part 'memory_backend_algo_vod.dart';
part 'memory_backend_algo_time.dart';
part 'memory_backend_algorithms.dart';
part 'memory_backend_sync.dart';
part 'memory_backend_recommendations.dart';
part 'memory_backend_reco_sections.dart';
part 'memory_backend_reco_trending.dart';

/// Pure in-memory [CrispyBackend] for testing.
///
/// All data is stored in plain Dart maps and
/// lists, discarded when garbage-collected.
///
/// Split across part files:
/// - [_MemoryChannelsMixin] — channels,
///   favorites, categories, channel order
/// - [_MemoryVodMixin] — VOD items, favorites
/// - [_MemoryEpgMixin] — EPG, watch history
/// - [_MemoryDvrMixin] — recordings, storage,
///   transfer tasks
/// - [_MemoryProfilesMixin] — profiles, access
/// - [_MemorySettingsMixin] — settings, sync,
///   image cache, layouts, search, reminders
/// - [_MemoryParsersMixin] — parser stubs,
///   Stalker/Xtream parsers, search, S3
/// - [_MemoryAlgorithmsMixin] — sorting,
///   categories, dedup, normalize, timezone
/// - [_MemorySyncMixin] — backup, cloud merge,
///   S3, Xtream URLs, PIN hashing
/// - [_MemoryRecommendationsMixin] — reco
///   engine, section parsing/deserialization
class MemoryBackend extends _MemoryStorage
    with
        _MemoryChannelsMixin,
        _MemoryVodMixin,
        _MemoryEpgMixin,
        _MemoryDvrMixin,
        _MemoryProfilesMixin,
        _MemorySettingsMixin,
        _MemoryParsersMixin,
        _MemoryAlgoCoreMixin,
        _MemoryAlgoVodMixin,
        _MemoryAlgoTimeMixin,
        _MemoryAlgorithmsMixin,
        _MemorySyncMixin,
        _MemoryRecommendationsMixin
    implements CrispyBackend {
  final _eventController = StreamController<String>.broadcast();

  // ── Lifecycle ───────────────────────────────────

  @override
  Future<void> init(String dbPath) async {}

  @override
  String version() => '0.0.0-memory';

  @override
  Future<String> detectGpu() async {
    return '{"vendor":"Unknown","name":"Test GPU",'
        '"vram_mb":null,"supports_hw_vsr":false,'
        '"vsr_method":"None"}';
  }

  // ── Events ─────────────────────────────────────

  @override
  Stream<String> get dataEvents => _eventController.stream;

  /// Inject a synthetic event for testing.
  void emitTestEvent(String jsonEvent) => _eventController.add(jsonEvent);

  // ── Maintenance ────────────────────────────────

  @override
  Future<void> clearAll() async {
    channels.clear();
    vodItems.clear();
    epg.clear();
    watchHistory.clear();
    settings.clear();
    syncTimes.clear();
    profiles.clear();
    favorites.clear();
    vodFavorites.clear();
    favCategories.clear();
    sourceAccess.clear();
    channelOrders.clear();
    categories.clear();
    recordings.clear();
    storageBackends.clear();
    transferTasks.clear();
    imageCache.clear();
    savedLayouts.clear();
    searchHistory.clear();
    reminders.clear();
  }
}

/// Internal storage maps shared by all mixins.
///
/// Visible to part files via library-private scope.
class _MemoryStorage {
  // ── Storage ─────────────────────────────────────

  final channels = <String, Map<String, dynamic>>{};
  final vodItems = <String, Map<String, dynamic>>{};
  final epg = <String, List<Map<String, dynamic>>>{};
  final watchHistory = <String, Map<String, dynamic>>{};
  final settings = <String, String>{};
  final syncTimes = <String, int>{};
  final profiles = <String, Map<String, dynamic>>{};
  final favorites = <String, Set<String>>{};
  final vodFavorites = <String, Set<String>>{};
  final favCategories = <String, Set<String>>{};
  final sourceAccess = <String, List<String>>{};
  final channelOrders = <String, List<String>>{};
  final categories = <String, List<String>>{};
  final recordings = <String, Map<String, dynamic>>{};
  final storageBackends = <String, Map<String, dynamic>>{};
  final transferTasks = <String, Map<String, dynamic>>{};
  final imageCache = <String, String>{};
  final savedLayouts = <String, Map<String, dynamic>>{};
  final searchHistory = <String, Map<String, dynamic>>{};
  final reminders = <String, Map<String, dynamic>>{};
}
