import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../epg/presentation/widgets/epg_channel_row.dart';
import '../../../epg/presentation/widgets/epg_program_block.dart';
import '../../../epg/presentation/widgets/epg_state_helpers.dart';
import '../../../epg/presentation/widgets/virtual_epg_grid.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../providers/player_providers.dart';

/// EPG guide panel shown on the right half of the screen
/// in TV guide split-screen mode.
///
/// Displays a live EPG grid with channel selection support.
/// When the user taps a channel, playback switches to it.
class PlayerGuideSplit extends ConsumerStatefulWidget {
  const PlayerGuideSplit({
    required this.onChannelSelected,
    required this.onDismiss,
    super.key,
  });

  /// Called when the user selects a channel from the guide.
  final void Function(Channel channel) onChannelSelected;

  /// Called when the user wants to close the guide.
  final VoidCallback onDismiss;

  @override
  ConsumerState<PlayerGuideSplit> createState() => _PlayerGuideSplitState();
}

class _PlayerGuideSplitState extends ConsumerState<PlayerGuideSplit> {
  late final ScrollController _horizontalScroll;
  late final ScrollController _gridScroll;

  @override
  void initState() {
    super.initState();
    _horizontalScroll = ScrollController();
    _gridScroll = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNow();
      _fetchEpg();
    });
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _gridScroll.dispose();
    super.dispose();
  }

  void _scrollToNow() {
    if (!_horizontalScroll.hasClients) return;

    final clock = ref.read(epgClockProvider);
    final now = clock();
    final viewMode = ref.read(epgProvider).viewMode;
    final ppm = getEpgPixelsPerMinute(viewMode);
    final (startDate, _) = getEpgDateRange(viewMode, now);

    final minutesFromStart = now.difference(startDate).inMinutes;
    if (minutesFromStart < 0) return;

    final offset = (minutesFromStart * ppm) - 200;
    final target = offset.clamp(
      0.0,
      _horizontalScroll.position.maxScrollExtent,
    );
    _horizontalScroll.jumpTo(target);
  }

  void _fetchEpg() {
    final clock = ref.read(epgClockProvider);
    final now = clock();
    final viewMode = ref.read(epgProvider).viewMode;
    final (start, end) = getEpgDateRange(viewMode, now);
    ref.read(epgProvider.notifier).fetchEpgWindow(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(epgProvider);
    final clock = ref.watch(epgClockProvider);
    final now = clock();
    final timezone = ref.watch(epgTimezoneProvider);
    final playingUrl = ref.watch(
      playbackSessionProvider.select((s) => s.streamUrl),
    );

    final viewMode = state.viewMode;
    final (startDate, endDate) = getEpgDateRange(viewMode, now);
    final ppm = getEpgPixelsPerMinute(viewMode);

    final effectiveEntries = <String, List<EpgEntry>>{...state.entries};
    for (final entry in state.epgOverrides.entries) {
      final target = state.entries[entry.value];
      if (target != null) {
        effectiveEntries[entry.key] = target;
      }
    }

    final channels = state.filteredChannels;

    if (channels.isEmpty) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Text(
            'No channels with EPG data',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black87,
      child: Column(
        children: [
          // Header bar with title and close button.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.md,
              vertical: CrispySpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.live_tv, color: Colors.white70, size: 20),
                const SizedBox(width: CrispySpacing.sm),
                Text(
                  'Program Guide',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: widget.onDismiss,
                  tooltip: 'Close Guide (G)',
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          // EPG grid.
          Expanded(
            child: FocusTraversalGroup(
              child: VirtualEpgGrid(
                channels: channels,
                epgEntries: effectiveEntries,
                startDate: startDate,
                endDate: endDate,
                pixelsPerMinute: ppm,
                viewMode: viewMode,
                timezone: timezone,
                clock: clock,
                horizontalScrollController: _horizontalScroll,
                verticalScrollController: _gridScroll,
                channelBuilder: (context, channel) {
                  final nowPlaying = state.getNowPlaying(channel.id, now: now);
                  final isPlaying =
                      channel.streamUrl.isNotEmpty &&
                      channel.streamUrl == playingUrl;

                  return EpgChannelRow(
                    channel: channel,
                    nowPlaying: nowPlaying,
                    isSelected: false,
                    isPlaying: isPlaying,
                    onTap: () => widget.onChannelSelected(channel),
                  );
                },
                programBuilder: (context, entry, w, h) {
                  return EpgProgramBlock(
                    entry: entry,
                    pixelsPerMinute: ppm,
                    onTap: () {
                      // Tapping a live programme plays that channel.
                      if (entry.isLive) {
                        final ch = channels.firstWhere(
                          (c) =>
                              c.id == entry.channelId ||
                              c.tvgId == entry.channelId,
                          orElse:
                              () => Channel(
                                id: entry.channelId,
                                name: 'Unknown',
                                streamUrl: '',
                              ),
                        );
                        if (ch.streamUrl.isNotEmpty) {
                          widget.onChannelSelected(ch);
                        }
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
