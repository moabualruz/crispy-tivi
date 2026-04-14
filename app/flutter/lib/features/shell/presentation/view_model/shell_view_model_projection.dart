part of 'shell_view_model.dart';

ShellRoute resolveShellStartupRoute(
  PersonalizationRuntimeSnapshot personalization,
  ShellContractSupport contract,
  SourceRegistrySnapshot? sourceRegistry,
) {
  if (sourceRegistry == null || sourceRegistry.configuredProviders.isEmpty) {
    return ShellRoute.settings;
  }
  for (final ShellRoute route in contract.topLevelRoutes) {
    if (route.label == personalization.startupRoute) {
      return route;
    }
  }
  return contract.startupRoute;
}

List<ShelfItem> buildContinueWatchingItems(
  PersonalizationRuntimeSnapshot personalizationRuntime,
) {
  final List<PersistentPlaybackEntry> entries =
      personalizationRuntime.continueWatching;
  if (entries.isEmpty) {
    return const <ShelfItem>[];
  }
  return List<ShelfItem>.unmodifiable(
    entries.map((PersistentPlaybackEntry entry) => entry.toShelfItem()),
  );
}

HeroFeature? heroFeatureFromRuntime(MediaRuntimeSnapshot mediaRuntime) {
  if (mediaRuntime.movieHero.title.isNotEmpty) {
    return _heroFeatureFromSnapshot(mediaRuntime.movieHero);
  }
  if (mediaRuntime.seriesHero.title.isNotEmpty) {
    return _heroFeatureFromSnapshot(mediaRuntime.seriesHero);
  }
  return null;
}

List<ShelfItem> buildLiveNowItems(LiveTvRuntimeSnapshot liveTvRuntime) {
  return List<ShelfItem>.unmodifiable(
    liveTvRuntime.channels.take(6).map((LiveTvRuntimeChannelSnapshot channel) {
      return ShelfItem(
        title: channel.name,
        caption: channel.current.title,
        artwork: null,
      );
    }),
  );
}

List<SettingsItem> buildGeneralSettingsItems({
  required PersonalizationRuntimeSnapshot personalizationRuntime,
  required SourceProviderRegistry sourceRegistry,
}) {
  return <SettingsItem>[
    SettingsItem(
      title: 'Startup route',
      summary: 'Route restored on launch when user state already exists.',
      value: personalizationRuntime.startupRoute,
    ),
    SettingsItem(
      title: 'Configured providers',
      summary: 'Providers currently connected on this runtime path.',
      value: '${sourceRegistry.configuredProviders.length}',
    ),
    SettingsItem(
      title: 'Provider catalog',
      summary: 'Available provider types for source setup.',
      value: '${sourceRegistry.providerTypes.length}',
    ),
  ];
}

List<SettingsItem> buildPlaybackSettingsItems(
  PersonalizationRuntimeSnapshot personalizationRuntime,
) {
  return <SettingsItem>[
    SettingsItem(
      title: 'Continue watching',
      summary: 'Resume-ready playback entries stored in personalization.',
      value: '${personalizationRuntime.continueWatching.length}',
    ),
    SettingsItem(
      title: 'Recent playback',
      summary: 'Recently viewed entries remembered by the runtime.',
      value: '${personalizationRuntime.recentlyViewed.length}',
    ),
    SettingsItem(
      title: 'Player backend',
      summary: 'Retained playback surface uses the integrated media backend.',
      value: 'media_kit',
    ),
  ];
}

List<SettingsItem> buildAppearanceSettingsItems() {
  return const <SettingsItem>[
    SettingsItem(
      title: 'Stage size',
      summary: 'Shell stays fixed to the product-sized 1080p stage.',
      value: '1920 × 1080',
    ),
    SettingsItem(
      title: 'Direction',
      summary: 'Shell alignment follows directional layout rules.',
      value: 'LTR',
    ),
    SettingsItem(
      title: 'Locale',
      summary: 'Active installed locale on this runtime baseline.',
      value: 'English',
    ),
  ];
}

List<SettingsItem> buildSystemSettingsItems(
  DiagnosticsRuntimeSnapshot diagnosticsRuntime,
) {
  return <SettingsItem>[
    SettingsItem(
      title: 'Diagnostics reports',
      summary: 'Runtime validation reports currently exposed to Settings.',
      value: '${diagnosticsRuntime.reports.length}',
    ),
    SettingsItem(
      title: 'ffprobe',
      summary: 'Host diagnostics for media inspection.',
      value: diagnosticsRuntime.ffprobeAvailable ? 'Ready' : 'Unavailable',
    ),
    SettingsItem(
      title: 'ffmpeg',
      summary: 'Host diagnostics for media processing.',
      value: diagnosticsRuntime.ffmpegAvailable ? 'Ready' : 'Unavailable',
    ),
  ];
}

HeroFeature _heroFeatureFromSnapshot(MediaRuntimeHeroSnapshot hero) {
  return HeroFeature(
    kicker: hero.kicker,
    title: hero.title,
    summary: hero.summary,
    primaryAction: hero.primaryAction,
    secondaryAction: hero.secondaryAction,
    artwork: hero.artwork,
  );
}
