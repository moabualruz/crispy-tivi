import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../core/theme/theme.dart';
import '../features/iptv/domain/entities/channel.dart';
import '../features/iptv/presentation/widgets/channel_grid_item.dart';
import '../features/iptv/presentation/widgets/channel_list_item.dart';
import '../features/settings/presentation/widgets/settings_shared_widgets.dart';
import '../features/vod/domain/entities/vod_item.dart';
import '../features/vod/presentation/widgets/episode_tile.dart';
import '../features/vod/presentation/widgets/vod_detail_actions.dart';
import '../features/vod/presentation/widgets/vod_detail_metadata.dart';
import 'catalog_surface.dart';

const _sampleChannel = Channel(
  id: 'sample-news',
  name: 'Crispy News HD',
  streamUrl: 'https://example.invalid/news.m3u8',
  number: 12,
  group: 'News',
  isFavorite: true,
  hasCatchup: true,
  catchupDays: 7,
  resolution: 'FHD',
);

const _sampleSportsChannel = Channel(
  id: 'sample-sports',
  name: 'Match Day Sports',
  streamUrl: 'https://example.invalid/sports.m3u8',
  number: 108,
  group: 'Sports',
  hasCatchup: true,
  catchupDays: 3,
  resolution: '4K',
  isSport: true,
);

const _sampleEpisode = VodItem(
  id: 'sample-episode',
  name: 'The Long Night',
  streamUrl: 'https://example.invalid/episode.mp4',
  type: VodType.episode,
  description: 'The crew follows a strange signal through a dark nebula.',
  duration: 47,
  year: 2026,
  seasonNumber: 2,
  episodeNumber: 4,
);

@widgetbook.UseCase(
  name: 'Program row states',
  type: ChannelListItem,
  path: '[Feature widgets]/ChannelListItem',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - Live TV Widgets',
)
Widget channelListItemUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 720,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChannelListItem(
            channel: _sampleChannel,
            currentProgram: 'Morning Briefing',
            programProgress: 0.42,
            nextProgramLabel: 'Next: Market Watch - 09:30',
            isPlaying: true,
            isInSmartGroup: true,
            onTap: () {},
            onToggleFavorite: () {},
          ),
          const SizedBox(height: CrispySpacing.sm),
          ChannelListItem(
            channel: _sampleSportsChannel,
            currentProgram: 'Championship Live',
            programProgress: 0.76,
            nextProgramLabel: 'Next: Post Match - 22:00',
            isDuplicate: true,
            onTap: () {},
          ),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Grid tile states',
  type: ChannelGridItem,
  path: '[Feature widgets]/ChannelGridItem',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - Live TV Widgets',
)
Widget channelGridItemUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 420,
      child: Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.2,
              child: ChannelGridItem(
                channel: _sampleChannel,
                onTap: () {},
                currentProgram: 'Morning Briefing',
                isPlaying: true,
              ),
            ),
          ),
          const SizedBox(width: CrispySpacing.md),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.2,
              child: ChannelGridItem(
                channel: _sampleSportsChannel,
                onTap: () {},
                currentProgram: 'Championship Live',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Badges',
  type: SettingsBadge,
  path: '[Feature widgets]/SettingsBadge',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - Settings Widgets',
)
Widget settingsBadgeUseCase(BuildContext context) {
  return const CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.md,
      runSpacing: CrispySpacing.md,
      children: [SettingsBadge.experimental(), SettingsBadge.comingSoon()],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Settings group',
  type: SettingsCard,
  path: '[Feature widgets]/SettingsCard',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - Settings Widgets',
)
Widget settingsCardUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 520,
      child: SettingsCard(
        children: [
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Auto resume last channel'),
            subtitle: const Text('Start playback when Live TV opens.'),
          ),
          const Divider(height: 1, indent: kSettingsIndent),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const SettingsTileTitle(
              title: 'Theme preview',
              badge: SettingsBadge.experimental(),
            ),
            subtitle: const Text('Warm black with Crispy red accent.'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Quality labels',
  type: QualityBadge,
  path: '[Feature widgets]/QualityBadge',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - VOD Widgets',
)
Widget qualityBadgeUseCase(BuildContext context) {
  return const CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.md,
      runSpacing: CrispySpacing.md,
      children: [
        QualityBadge(label: 'HD'),
        QualityBadge(label: 'FHD'),
        QualityBadge(label: '4K'),
        QualityBadge(label: 'HDR'),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Secondary actions',
  type: CircularAction,
  path: '[Feature widgets]/CircularAction',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - VOD Widgets',
)
Widget circularActionUseCase(BuildContext context) {
  return CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.xl,
      runSpacing: CrispySpacing.lg,
      children: [
        CircularAction(icon: Icons.add, label: 'My List', onTap: () {}),
        CircularAction(icon: Icons.check, label: 'Saved', onTap: () {}),
        CircularAction(
          icon: Icons.thumb_up_outlined,
          label: 'Rate',
          onTap: () {},
        ),
        CircularAction(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () {},
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Episode row states',
  type: EpisodeTile,
  path: '[Feature widgets]/EpisodeTile',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - VOD Widgets',
)
Widget episodeTileUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 760,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EpisodeTile(
            episode: _sampleEpisode,
            progress: 0.42,
            isLastWatched: true,
            onTap: () {},
            onToggleWatched: () {},
          ),
          const SizedBox(height: CrispySpacing.sm),
          EpisodeTile(
            episode: _sampleEpisode.copyWith(
              id: 'sample-episode-next',
              name: 'After the Signal',
              episodeNumber: 5,
              description: 'The next jump reveals the source of the message.',
            ),
            progress: 0,
            isUpNext: true,
            onTap: () {},
            onToggleWatched: () {},
          ),
          const SizedBox(height: CrispySpacing.sm),
          EpisodeTile(
            episode: _sampleEpisode.copyWith(
              id: 'sample-episode-watched',
              name: 'Signal Found',
              episodeNumber: 6,
              duration: 51,
            ),
            progress: 1,
            onTap: () {},
            onToggleWatched: () {},
          ),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Synopsis collapsed',
  type: ExpandableSynopsis,
  path: '[Feature widgets]/ExpandableSynopsis',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - VOD Widgets',
)
Widget expandableSynopsisUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 560,
      child: ExpandableSynopsis(
        text:
            'A team of explorers uncovers a forgotten broadcast that points to '
            'a lost archive of classic films, live recordings, and impossible '
            'signals from beyond the edge of known space.',
        textTheme: Theme.of(context).textTheme,
      ),
    ),
  );
}
