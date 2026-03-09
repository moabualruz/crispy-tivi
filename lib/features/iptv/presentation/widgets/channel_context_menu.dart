import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/utils/stream_url_actions.dart';
import '../../../../core/widgets/context_menu_builders.dart';
import '../../../../core/widgets/context_menu_panel.dart';
import '../../../epg/presentation/widgets/epg_assign_dialog.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../player/presentation/screens/multi_view_screen.dart';
import '../../domain/entities/channel.dart';
import '../providers/channel_providers.dart';
import 'smart_channel_sheet.dart';
import 'stream_failover_sheet.dart';

/// Shows the channel long-press context menu.
///
/// Encapsulates all context menu actions (favorite,
/// EPG assign, hide, block, copy URL, external
/// player, stream failover) so the main screen stays slim.
void showChannelContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Channel channel,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  showContextMenuPanel(
    context: context,
    sections: buildChannelContextMenu(
      context: context,
      channelName: channel.name,
      isFavorite: channel.isFavorite,
      colorScheme: colorScheme,
      onToggleFavorite:
          () =>
              ref.read(channelListProvider.notifier).toggleFavorite(channel.id),
      // FE-TV-10: always show "Switch stream source" — users can
      // try the primary URL again or it becomes useful once
      // extra backup URLs are wired in by the data layer.
      onSwitchStream:
          () =>
              _showFailoverSheet(context: context, ref: ref, channel: channel),
      onSmartGroup:
          () => showSmartChannelSheet(
            context: context,
            ref: ref,
            preselectedChannelId: channel.id,
          ),
      onAssignEpg:
          () => showDialog(
            context: context,
            builder: (_) => EpgAssignDialog(channel: channel),
          ),
      onHide: () {
        ref.read(settingsNotifierProvider.notifier).hideChannel(channel.id);
        ref
            .read(channelListProvider.notifier)
            .setHiddenChannelIds(
              ref.read(settingsNotifierProvider).value?.allHiddenChannelIds ??
                  {channel.id},
            );
      },
      onBlock: () {
        ref.read(settingsNotifierProvider.notifier).blockChannel(channel.id);
        ref
            .read(channelListProvider.notifier)
            .setHiddenChannelIds(
              ref.read(settingsNotifierProvider).value?.allHiddenChannelIds ??
                  {channel.id},
            );
      },
      onMultiView: () {
        final channels = ref.read(channelListProvider).filteredChannels;
        final idx = channels.indexWhere((c) => c.id == channel.id);
        final start = idx >= 0 ? idx : 0;
        final subset =
            channels
                .skip(start)
                .where((c) => c.streamUrl.isNotEmpty)
                .take(9)
                .toList();
        if (subset.isNotEmpty && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MultiViewScreen(channels: subset),
            ),
          );
        }
      },
      onCopyUrl: () => copyStreamUrl(context, channel.streamUrl),
      onOpenExternal:
          hasExternalPlayer(ref)
              ? () => openInExternalPlayer(
                context: context,
                ref: ref,
                streamUrl: channel.streamUrl,
                title: channel.name,
              )
              : null,
    ),
  );
}

/// Opens [StreamFailoverSheet] for [channel] and starts playback
/// of the selected stream.
///
/// Currently each [Channel] carries a single [Channel.streamUrl].
/// When the data layer exposes backup URLs, pass them as
/// [extraUrls]. The primary stream is always listed first.
void _showFailoverSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Channel channel,
  List<String> extraUrls = const [],
}) {
  final options = buildStreamOptions(channel, extraUrls: extraUrls);
  final currentUrl =
      ref.read(channelStreamOverrideProvider)[channel.id] ?? channel.streamUrl;

  showStreamFailoverSheet(
    context: context,
    ref: ref,
    channel: channel,
    options: options,
    currentUrl: currentUrl,
    onStreamSelected: (option) {
      // Persist the override for this channel so the picker
      // reflects the last-selected URL on next open.
      ref
          .read(channelStreamOverrideProvider.notifier)
          .setUrl(channel.id, option.url);

      // Play the selected stream immediately.
      final ps = ref.read(playerServiceProvider);
      ps.play(
        option.url,
        isLive: true,
        channelName: channel.name,
        channelLogoUrl: channel.logoUrl,
        headers:
            channel.userAgent != null
                ? {'User-Agent': channel.userAgent!}
                : null,
      );

      ref
          .read(playbackSessionProvider.notifier)
          .startPreview(
            streamUrl: option.url,
            isLive: true,
            channelName: channel.name,
            channelLogoUrl: channel.logoUrl,
            headers:
                channel.userAgent != null
                    ? {'User-Agent': channel.userAgent!}
                    : null,
          );

      ref.read(playerServiceProvider).forceStateEmit();
    },
  );
}
