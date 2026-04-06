// Re-export file: routes data-layer symbols into the presentation layer.
// Providers import from here instead of directly from data/.
export '../../../profiles/data/profile_service.dart'
    show ProfileService, profileServiceProvider;
export '../../data/repositories/favorites_repository_impl.dart'
    show FavoritesRepositoryImpl, favoritesRepositoryProvider;
export '../../data/stalker_favorites_service.dart'
    show StalkerFavoritesService, stalkerFavoritesServiceProvider;
