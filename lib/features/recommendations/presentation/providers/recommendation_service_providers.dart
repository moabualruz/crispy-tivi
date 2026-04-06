// Re-export file: routes data-layer symbols into the presentation layer.
// Providers import from here instead of directly from data/.
export '../../../../core/data/cache_service.dart'
    show CacheService, cacheServiceProvider, crispyBackendProvider;
export '../../../profiles/data/profile_service.dart'
    show ProfileService, profileServiceProvider;
export '../../data/recommendation_engine.dart'
    show RecommendationEngine, UserSignals, WatchSignal;
