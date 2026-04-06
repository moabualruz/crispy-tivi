/// Re-exports for IPTV presentation layer.
///
/// Widgets in [iptv/presentation/widgets/] must import from this file
/// instead of reaching directly into data/ layers (DIP / ISP compliance).
export '../../../../core/data/cache_service.dart'
    show CacheService, cacheServiceProvider, crispyBackendProvider, encodeChannelsJson;
export '../../../../core/data/crispy_backend.dart' show CrispyBackend;
export '../../../favorites/data/favorites_history_service.dart'
    show
        FavoritesHistoryService,
        FavoritesHistoryState,
        favoritesHistoryProvider;
export '../../data/sync_report_codec.dart' show SyncReport, decodeSyncReport;
