import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';

const HeroFeature movieHero = HeroFeature(
  kicker: 'Featured film',
  title: 'The Last Harbor',
  summary:
      'A cinematic detail state with clear action hierarchy, restrained metadata, and content-first framing.',
  primaryAction: 'Play trailer',
  secondaryAction: 'Add to watchlist',
  backgroundAsset: 'assets/mocks/media-movie-hero.jpg',
);

const HeroFeature seriesHero = HeroFeature(
  kicker: 'Series spotlight',
  title: 'Shadow Signals',
  summary:
      'Season-driven browsing stays inside the media domain with episode context and tight focus separation.',
  primaryAction: 'Resume S1:E6',
  secondaryAction: 'Browse episodes',
  backgroundAsset: 'assets/mocks/media-series-hero.jpg',
);

const List<ShelfItem> topFilms = <ShelfItem>[
  ShelfItem(
    title: 'The Last Harbor',
    caption: 'Thriller',
    rank: 1,
    imageAsset: 'assets/mocks/poster-1.jpg',
  ),
  ShelfItem(
    title: 'Glass Minute',
    caption: 'Drama',
    rank: 2,
    imageAsset: 'assets/mocks/poster-2.jpg',
  ),
  ShelfItem(
    title: 'Wired North',
    caption: 'Sci-fi',
    rank: 3,
    imageAsset: 'assets/mocks/poster-3.jpg',
  ),
  ShelfItem(
    title: 'Quiet Ember',
    caption: 'Mystery',
    rank: 4,
    imageAsset: 'assets/mocks/poster-4.jpg',
  ),
  ShelfItem(
    title: 'Atlas Run',
    caption: 'Action',
    rank: 5,
    imageAsset: 'assets/mocks/poster-5.jpg',
  ),
];

const List<ShelfItem> topSeries = <ShelfItem>[
  ShelfItem(
    title: 'Shadow Signals',
    caption: 'New episode',
    rank: 1,
    imageAsset: 'assets/mocks/poster-5.jpg',
  ),
  ShelfItem(
    title: 'Northline',
    caption: 'Season finale',
    rank: 2,
    imageAsset: 'assets/mocks/poster-4.jpg',
  ),
  ShelfItem(
    title: 'Open Range',
    caption: 'Continue watching',
    rank: 3,
    imageAsset: 'assets/mocks/poster-3.jpg',
  ),
  ShelfItem(
    title: 'Fifth Harbor',
    caption: 'New season',
    rank: 4,
    imageAsset: 'assets/mocks/poster-2.jpg',
  ),
  ShelfItem(
    title: 'After Current',
    caption: 'Trending',
    rank: 5,
    imageAsset: 'assets/mocks/poster-1.jpg',
  ),
];
