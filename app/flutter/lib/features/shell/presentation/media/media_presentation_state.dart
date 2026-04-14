import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';

final class MediaPresentationState {
  const MediaPresentationState({
    required this.availableScopes,
    required this.panel,
    required this.scope,
    required this.movieHero,
    required this.seriesHero,
    required this.seriesDetail,
    required this.topFilms,
    required this.topSeries,
    required this.continueWatching,
    required this.seriesSeasonIndex,
    required this.seriesEpisodeIndex,
    required this.launchedSeriesEpisodeIndex,
    required this.watchlistItems,
  });

  factory MediaPresentationState.fromRuntime({
    required MediaRuntimeSnapshot runtime,
    required PersonalizationRuntimeSnapshot personalization,
    required List<MediaScope> availableScopes,
    required MediaPanel panel,
    required MediaScope scope,
    required int seriesSeasonIndex,
    required int seriesEpisodeIndex,
    required int? launchedSeriesEpisodeIndex,
  }) {
    final List<ShelfItem> movieShelf = _adaptShelfItems(
      runtime.movieCollections.isNotEmpty
          ? runtime.movieCollections.first
          : null,
    );
    final List<ShelfItem> movieContinueWatching =
        personalization.entriesForMovieContinueWatching().isNotEmpty
            ? personalization
                .entriesForMovieContinueWatching()
                .map((PersistentPlaybackEntry entry) => entry.toShelfItem())
                .toList(growable: false)
            : _adaptShelfItems(
              runtime.movieCollections.length > 1
                  ? runtime.movieCollections[1]
                  : null,
            );
    final List<ShelfItem> seriesShelf = _adaptShelfItems(
      runtime.seriesCollections.isNotEmpty
          ? runtime.seriesCollections.first
          : null,
    );
    final List<ShelfItem> seriesContinueWatching =
        personalization.entriesForSeriesContinueWatching().isNotEmpty
            ? personalization
                .entriesForSeriesContinueWatching()
                .map((PersistentPlaybackEntry entry) => entry.toShelfItem())
                .toList(growable: false)
            : _adaptShelfItems(
              runtime.seriesCollections.length > 1
                  ? runtime.seriesCollections[1]
                  : null,
            );
    final List<ShelfItem> movieRecent = personalization
        .entriesForRecentMovies()
        .map((PersistentPlaybackEntry entry) => entry.toShelfItem())
        .toList(growable: false);
    final List<ShelfItem> seriesRecent = personalization
        .entriesForRecentSeries()
        .map((PersistentPlaybackEntry entry) => entry.toShelfItem())
        .toList(growable: false);
    final List<ShelfItem> movieWatchlist = personalization
        .entriesForWatchlistMovies()
        .map((PersistentPlaybackEntry entry) => entry.toShelfItem())
        .toList(growable: false);
    final List<ShelfItem> seriesWatchlist = personalization
        .entriesForWatchlistSeries()
        .map((PersistentPlaybackEntry entry) => entry.toShelfItem())
        .toList(growable: false);
    return MediaPresentationState(
      availableScopes: availableScopes,
      panel: panel,
      scope: scope,
      movieHero: _adaptHero(runtime.movieHero),
      seriesHero: _adaptHero(runtime.seriesHero),
      seriesDetail: _adaptSeriesDetail(runtime.seriesDetail),
      topFilms: switch (scope) {
        MediaScope.recent when movieRecent.isNotEmpty => movieRecent,
        MediaScope.library when movieWatchlist.isNotEmpty => movieWatchlist,
        _ => movieShelf,
      },
      topSeries: switch (scope) {
        MediaScope.recent when seriesRecent.isNotEmpty => seriesRecent,
        MediaScope.library when seriesWatchlist.isNotEmpty => seriesWatchlist,
        _ => seriesShelf,
      },
      continueWatching:
          panel == MediaPanel.movies
              ? movieContinueWatching
              : seriesContinueWatching,
      seriesSeasonIndex: seriesSeasonIndex,
      seriesEpisodeIndex: seriesEpisodeIndex,
      launchedSeriesEpisodeIndex: launchedSeriesEpisodeIndex,
      watchlistItems:
          panel == MediaPanel.movies ? movieWatchlist : seriesWatchlist,
    );
  }

  const MediaPresentationState.empty()
    : availableScopes = const <MediaScope>[],
      panel = MediaPanel.movies,
      scope = MediaScope.featured,
      movieHero = HeroFeature.empty,
      seriesHero = HeroFeature.empty,
      seriesDetail = SeriesDetailContent.empty,
      topFilms = const <ShelfItem>[],
      topSeries = const <ShelfItem>[],
      continueWatching = const <ShelfItem>[],
      seriesSeasonIndex = 0,
      seriesEpisodeIndex = 0,
      launchedSeriesEpisodeIndex = null,
      watchlistItems = const <ShelfItem>[];

  final List<MediaScope> availableScopes;
  final MediaPanel panel;
  final MediaScope scope;
  final HeroFeature movieHero;
  final HeroFeature seriesHero;
  final SeriesDetailContent seriesDetail;
  final List<ShelfItem> topFilms;
  final List<ShelfItem> topSeries;
  final List<ShelfItem> continueWatching;
  final int seriesSeasonIndex;
  final int seriesEpisodeIndex;
  final int? launchedSeriesEpisodeIndex;
  final List<ShelfItem> watchlistItems;

  bool get movies => panel == MediaPanel.movies;

  bool get hasContent {
    return movieHero.title.isNotEmpty ||
        seriesHero.title.isNotEmpty ||
        topFilms.isNotEmpty ||
        topSeries.isNotEmpty ||
        continueWatching.isNotEmpty ||
        watchlistItems.isNotEmpty ||
        seriesDetail.seasons.isNotEmpty;
  }
}

HeroFeature _adaptHero(MediaRuntimeHeroSnapshot hero) {
  return HeroFeature(
    kicker: hero.kicker,
    title: hero.title,
    summary: hero.summary,
    primaryAction: hero.primaryAction,
    secondaryAction: hero.secondaryAction,
    artwork: hero.artwork,
  );
}

SeriesDetailContent _adaptSeriesDetail(MediaRuntimeSeriesDetailSnapshot detail) {
  return SeriesDetailContent(
    summaryTitle: detail.summaryTitle,
    summaryBody: detail.summaryBody,
    handoffLabel: detail.handoffLabel,
    seasons: detail.seasons.map(_adaptSeason).toList(growable: false),
  );
}

SeriesSeasonDetail _adaptSeason(MediaRuntimeSeasonSnapshot season) {
  return SeriesSeasonDetail(
    label: season.label,
    summary: season.summary,
    episodes: season.episodes.map(_adaptEpisode).toList(growable: false),
  );
}

SeriesEpisodeDetail _adaptEpisode(MediaRuntimeEpisodeSnapshot episode) {
  return SeriesEpisodeDetail(
    code: episode.code,
    title: episode.title,
    summary: episode.summary,
    durationLabel: episode.durationLabel,
    handoffLabel: episode.handoffLabel,
  );
}

List<ShelfItem> _adaptShelfItems(MediaRuntimeCollectionSnapshot? collection) {
  if (collection == null) {
    return const <ShelfItem>[];
  }
  return List<ShelfItem>.unmodifiable(
    collection.items
        .map(
          (MediaRuntimeItemSnapshot item) => ShelfItem(
            title: item.title,
            caption: item.caption,
            rank: item.rank,
            artwork: item.artwork,
          ),
        )
        .toList(growable: false),
  );
}
