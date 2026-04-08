/// Re-exports [favoritesHistoryProvider] and related types from the
/// data layer so presentation widgets can import from the correct
/// architectural layer without crossing into `data/` directly.
library;

export '../../data/favorites_history_service.dart'
    show
        FavoritesHistoryService,
        FavoritesHistoryState,
        WatchPosition,
        favoritesHistoryProvider;
