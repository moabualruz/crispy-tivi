/// Re-exports for VOD presentation layer.
///
/// Widgets in [vod/presentation/widgets/] must import from this file
/// instead of reaching directly into data/ layers (DIP / ISP compliance).
export '../../../../core/data/cache_service.dart'
    show CacheService, cacheServiceProvider, CrispyBackend, crispyBackendProvider;
export '../../../../core/data/dart_algorithm_fallbacks.dart'
    show dartResolveVodQuality;
export '../../../player/data/watch_history_service.dart'
    show WatchHistoryService, watchHistoryServiceProvider;
export '../../data/vod_detail_fetcher.dart' show fetchVodDetail;
export '../../data/vod_parser.dart' show VodParser;
export '../../data/vod_repository_impl.dart' show vodRepositoryProvider;
