enum ShellRoute {
  home('Home'),
  liveTv('Live TV'),
  media('Media'),
  search('Search'),
  settings('Settings');

  const ShellRoute(this.label);

  final String label;
}

const List<ShellRoute> mainNavigationRoutes = <ShellRoute>[
  ShellRoute.home,
  ShellRoute.liveTv,
  ShellRoute.media,
  ShellRoute.search,
];

enum LiveTvPanel {
  channels('Channels'),
  guide('Guide');

  const LiveTvPanel(this.label);

  final String label;
}

enum LiveTvGroup {
  allChannels('All'),
  favorites('Favorites'),
  news('News'),
  sports('Sports'),
  movies('Movies'),
  kids('Kids');

  const LiveTvGroup(this.label);

  final String label;
}

enum MediaPanel {
  movies('Movies'),
  series('Series');

  const MediaPanel(this.label);

  final String label;
}

enum MediaScope {
  featured('Featured'),
  trending('Trending'),
  recent('Recent'),
  library('Library');

  const MediaScope(this.label);

  final String label;
}

enum SettingsPanel {
  general('General'),
  playback('Playback'),
  sources('Sources'),
  appearance('Appearance'),
  system('System');

  const SettingsPanel(this.label);

  final String label;
}

enum SourceWizardStep {
  sourceType('Source Type'),
  connection('Connection'),
  credentials('Credentials'),
  importContent('Import'),
  finish('Finish');

  const SourceWizardStep(this.label);

  final String label;
}
