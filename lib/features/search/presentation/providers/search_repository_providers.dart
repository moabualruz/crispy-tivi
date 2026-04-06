// Re-exports repository providers defined in the data layer.
// This keeps presentation/providers/ free of direct CacheService imports
// while giving callers a single import path.
export '../../data/repositories/search_repository_impl.dart'
    show searchRepositoryProvider;
export '../../data/repositories/search_history_repository_impl.dart'
    show searchHistoryRepositoryProvider;
