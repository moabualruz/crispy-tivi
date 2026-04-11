import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';

const HeroFeature homeHero = HeroFeature(
  kicker: 'Tonight on CrispyTivi',
  title: 'City Lights at Midnight',
  summary:
      'A dramatic featured rail with quiet chrome, clear hierarchy, and room-readable action placement.',
  primaryAction: 'Resume watching',
  secondaryAction: 'Open details',
  backgroundAsset: 'assets/mocks/home-hero.jpg',
);

const List<ShelfItem> continueWatchingItems = <ShelfItem>[
  ShelfItem(
    title: 'Neon District',
    caption: '42 min left',
    imageAsset: 'assets/mocks/poster-1.jpg',
  ),
  ShelfItem(
    title: 'Chef After Dark',
    caption: 'Resume S2:E4',
    imageAsset: 'assets/mocks/poster-2.jpg',
  ),
  ShelfItem(
    title: 'Morning Live',
    caption: 'Live now',
    imageAsset: 'assets/mocks/poster-3.jpg',
  ),
  ShelfItem(
    title: 'The Signal',
    caption: 'Start over',
    imageAsset: 'assets/mocks/poster-4.jpg',
  ),
];

const List<ShelfItem> liveNowItems = <ShelfItem>[
  ShelfItem(
    title: 'World Report',
    caption: 'Newsroom',
    imageAsset: 'assets/mocks/poster-5.jpg',
  ),
  ShelfItem(
    title: 'Match Night',
    caption: 'Sports Central',
    imageAsset: 'assets/mocks/poster-1.jpg',
  ),
  ShelfItem(
    title: 'Cinema Vault',
    caption: 'Classic movies',
    imageAsset: 'assets/mocks/poster-2.jpg',
  ),
  ShelfItem(
    title: 'Planet North',
    caption: 'Nature HD',
    imageAsset: 'assets/mocks/poster-3.jpg',
  ),
];

const List<ShelfItem> quickAccessItems = <ShelfItem>[
  ShelfItem(title: 'Search', caption: 'Find channels, movies, settings'),
  ShelfItem(title: 'Settings', caption: 'System and playback controls'),
  ShelfItem(title: 'Sources', caption: 'Manage inputs inside Settings'),
  ShelfItem(title: 'Live TV Guide', caption: 'Jump into the schedule'),
];
