import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/group_sidebar.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../../../../core/widgets/video_preview_widget.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../providers/epg_providers.dart';
import 'epg_mobile_video_overlay.dart';
import 'epg_program_info_panel.dart';
import 'epg_whats_on_now_row.dart';

/// Mobile (compact) layout for the EPG timeline screen.
///
/// Stacks the app bar, source selector, optional "What's On Now"
/// row, and the EPG grid with the floating video overlay.
class EpgMobileLayout extends StatelessWidget {
  const EpgMobileLayout({
    required this.state,
    required this.appBar,
    required this.epgGrid,
    required this.onScrollToChannel,
    required this.onExpandPlayer,
    super.key,
  });

  final EpgState state;
  final PreferredSizeWidget appBar;
  final Widget epgGrid;
  final void Function(Channel) onScrollToChannel;
  final VoidCallback onExpandPlayer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: appBar.preferredSize.height, child: appBar),
        // Source filter bar (hidden when ≤1 source).
        const SourceSelectorBar(),
        // FE-EPG-10: "What's On Now" summary row (day view only).
        if (state.viewMode == EpgViewMode.day)
          EpgWhatsOnNowRow(onChannelTap: onScrollToChannel),
        Expanded(
          child: FocusTraversalGroup(
            child: Stack(
              children: [epgGrid, EpgMobileVideoOverlay(onTap: onExpandPlayer)],
            ),
          ),
        ),
      ],
    );
  }
}

/// TV / desktop (large) layout for the EPG timeline screen.
///
/// Renders a [GroupSidebar] on the left and the full EPG content
/// area (info panel + video preview + "What's On Now" + grid) on
/// the right.
class EpgTvLayout extends ConsumerWidget {
  const EpgTvLayout({
    required this.state,
    required this.appBar,
    required this.epgGrid,
    required this.onScrollToChannel,
    required this.onExpandPlayer,
    required this.onPlayEntry,
    required this.onRecordEntry,
    super.key,
  });

  final EpgState state;
  final PreferredSizeWidget appBar;
  final Widget epgGrid;
  final void Function(Channel) onScrollToChannel;
  final VoidCallback onExpandPlayer;
  final VoidCallback onPlayEntry;
  final VoidCallback onRecordEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final timezone = ref.watch(epgTimezoneProvider);

    return Row(
      children: [
        // ── Group Sidebar ──
        SidebarFocusScope(
          child: GroupSidebar(
            groups: state.groups,
            selectedGroup: state.selectedGroup,
            onGroupSelected: (group) {
              ref.read(epgProvider.notifier).selectGroup(group);
            },
            header: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
              child: Text(
                'Groups',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        // ── EPG Content Area ──
        Expanded(
          child: FocusTraversalGroup(
            child: Builder(
              builder: (context) {
                return Column(
                  children: [
                    SizedBox(
                      height: appBar.preferredSize.height,
                      child: appBar,
                    ),
                    // ── Top: Info + Video
                    // Info panel (Expanded) absorbs sidebar width
                    // changes; video stays anchored on the right
                    // so the Platform View doesn't need to move
                    // during sidebar animation.
                    SizedBox(
                      height: 180,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: EpgProgramInfoPanel(
                              entry: state.selectedEntry,
                              channels: state.channels,
                              timezone: timezone,
                              onWatch: onPlayEntry,
                              onRecord: onRecordEntry,
                            ),
                          ),
                          VideoPreviewWidget(onTap: onExpandPlayer),
                        ],
                      ),
                    ),
                    // FE-EPG-10: "What's On Now" row (day view only).
                    if (state.viewMode == EpgViewMode.day)
                      EpgWhatsOnNowRow(onChannelTap: onScrollToChannel),
                    // ── EPG Grid ──
                    Expanded(child: epgGrid),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
