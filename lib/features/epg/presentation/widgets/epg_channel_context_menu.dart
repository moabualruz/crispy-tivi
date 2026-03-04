import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/stream_url_actions.dart';
import '../../../../core/widgets/context_menu_panel.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../providers/epg_providers.dart';

/// Shows the TiviMate-style channel context menu.
///
/// All callbacks are provided by the caller so this
/// function stays free of direct provider/state writes.
void showEpgChannelContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Channel channel,
  required EpgEntry? nowPlaying,
  required VoidCallback onPlayChannel,
  required VoidCallback onOpenExternal,
  required VoidCallback onRecordNowPlaying,
  required VoidCallback onHideChannel,
  required VoidCallback onBlockChannel,
  required VoidCallback onAssignEpg,
  required VoidCallback onSearch,
  required bool hasExternal,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final isFavorite = channel.isFavorite;
  final epgState = ref.read(epgProvider);

  showContextMenuPanel(
    context: context,
    sections: [
      if (nowPlaying != null)
        ContextMenuSection(
          header: nowPlaying.title,
          headerColor: colorScheme.primary,
          items: [
            ContextMenuItem(
              icon: Icons.play_arrow,
              label: 'Watch',
              onTap: onPlayChannel,
            ),
            ContextMenuItem(
              icon: Icons.open_in_new,
              label: 'Open in external player',
              onTap: onOpenExternal,
            ),
            ContextMenuItem(
              icon: Icons.fiber_manual_record,
              label: 'Record',
              onTap: onRecordNowPlaying,
            ),
          ],
        ),
      ContextMenuSection(
        header: channel.name,
        headerColor: colorScheme.primary,
        items: [
          ContextMenuItem(
            icon: isFavorite ? Icons.star : Icons.star_outline,
            label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            onTap: () {
              ref.read(channelListProvider.notifier).toggleFavorite(channel.id);
            },
          ),
          ContextMenuItem(
            icon: Icons.visibility_off,
            label: 'Hide channel',
            onTap: onHideChannel,
          ),
          ContextMenuItem(
            icon: Icons.tv_rounded,
            label: 'Assign EPG',
            onTap: onAssignEpg,
          ),
          ContextMenuItem(
            icon: Icons.block,
            label: 'Block channel',
            isDestructive: true,
            onTap: onBlockChannel,
          ),
          ContextMenuItem(icon: Icons.search, label: 'Search', onTap: onSearch),
          ContextMenuItem(
            icon:
                epgState.showEpgOnly
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
            label:
                epgState.showEpgOnly
                    ? 'Show all channels'
                    : 'Show EPG channels only',
            onTap: () => ref.read(epgProvider.notifier).toggleEpgOnly(),
          ),
          ContextMenuItem(
            icon: Icons.copy,
            label: 'Copy stream URL',
            onTap: () => copyStreamUrl(context, channel.streamUrl),
          ),
          if (hasExternal)
            ContextMenuItem(
              icon: Icons.open_in_new,
              label: 'Play in external player',
              onTap:
                  () => openInExternalPlayer(
                    context: context,
                    ref: ref,
                    streamUrl: channel.streamUrl,
                    title: channel.name,
                  ),
            ),
        ],
      ),
    ],
  );
}
