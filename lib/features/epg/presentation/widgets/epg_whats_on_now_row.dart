import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/nav_arrow.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../providers/epg_providers.dart';

// ── Layout constants ────────────────────────────────────────

/// Height of the "What's On Now" summary row (px).
const double kEpgWhatsOnNowRowHeight = 96.0;

/// Width of each card in the "What's On Now" row (px).
const double _kCardWidth = 160.0;

/// Maximum number of channels shown in the row.
const int _kMaxChannels = 20;

/// Describes a single "now playing" entry shown in the
/// "What's On Now" summary row.
class _NowItem {
  const _NowItem({required this.channel, required this.entry});

  final Channel channel;
  final EpgEntry entry;
}

/// Horizontal scrolling "What's On Now" summary row (FE-EPG-10).
///
/// Shows currently-airing programmes for favorite channels (or
/// the first [_kMaxChannels] channels when no favorites exist).
/// Tapping a card calls [onChannelTap] so the parent can scroll
/// the EPG grid to that channel/timeslot.
///
/// Place this widget above the EPG grid. It uses [epgProvider]
/// to read channel + entry data — no additional data fetching.
class EpgWhatsOnNowRow extends ConsumerStatefulWidget {
  const EpgWhatsOnNowRow({required this.onChannelTap, super.key});

  /// Called when the user taps a card.
  ///
  /// Receives the [Channel] so the parent can scroll to it.
  final ValueChanged<Channel> onChannelTap;

  @override
  ConsumerState<EpgWhatsOnNowRow> createState() => _EpgWhatsOnNowRowState();
}

class _EpgWhatsOnNowRowState extends ConsumerState<EpgWhatsOnNowRow> {
  final _scrollController = ScrollController();
  bool _isHovered = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.enterCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(epgProvider);
    final clock = ref.watch(epgClockProvider);
    final now = clock();

    // Prefer favorites; fall back to first N channels.
    final favorites =
        state.filteredChannels.where((c) => c.isFavorite).toList();
    final pool = favorites.isNotEmpty ? favorites : state.filteredChannels;

    // Collect items that are currently airing.
    final items = <_NowItem>[];
    for (final channel in pool) {
      if (items.length >= _kMaxChannels) break;
      final entry = state.getNowPlaying(channel.id, now: now);
      if (entry != null) {
        items.add(_NowItem(channel: channel, entry: entry));
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: kEpgWhatsOnNowRowHeight,
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Padding(
            padding: const EdgeInsets.only(
              left: CrispySpacing.md,
              top: CrispySpacing.xs,
            ),
            child: Text(
              "What's On Now",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Cards
          Expanded(
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: Stack(
                children: [
                  ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.md,
                      vertical: CrispySpacing.xs,
                    ),
                    itemCount: items.length,
                    separatorBuilder:
                        (_, _) => const SizedBox(width: CrispySpacing.sm),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _NowCard(
                        item: item,
                        now: now,
                        onTap: () => widget.onChannelTap(item.channel),
                      );
                    },
                  ),
                  if (_isHovered)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 36,
                      child: NavArrow(
                        icon: Icons.chevron_left,
                        onTap: () => _scrollBy(-200),
                        isLeft: true,
                        iconSize: 20,
                      ),
                    ),
                  if (_isHovered)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 36,
                      child: NavArrow(
                        icon: Icons.chevron_right,
                        onTap: () => _scrollBy(200),
                        isLeft: false,
                        iconSize: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single card in the "What's On Now" row.
class _NowCard extends StatelessWidget {
  const _NowCard({required this.item, required this.now, required this.onTap});

  final _NowItem item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final remaining = item.entry.endTime.difference(now);
    final remainingMin = remaining.inMinutes.clamp(0, 9999);
    final progress = item.entry.progressAt(now);

    return Semantics(
      label:
          '${item.channel.name}: ${item.entry.title}, '
          '$remainingMin min remaining',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: _kCardWidth,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.sm,
                  vertical: CrispySpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Channel logo + name
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: SmartImage(
                            itemId: item.channel.id,
                            title: item.channel.name,
                            imageUrl: item.channel.logoUrl,
                            imageKind: 'logo',
                            fit: BoxFit.contain,
                            memCacheWidth: 40,
                            memCacheHeight: 40,
                          ),
                        ),
                        const SizedBox(width: CrispySpacing.xs),
                        Expanded(
                          child: Text(
                            item.channel.name,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CrispySpacing.xxs),
                    // Program title
                    Text(
                      item.entry.title,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: CrispySpacing.xxs),
                    // Time remaining
                    Text(
                      '$remainingMin min left',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Progress bar at the bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
