import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../home/presentation/widgets/vod_row.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/domain/entities/watch_history_entry.dart';
import '../../../player/presentation/providers/player_providers.dart';
import 'continue_watching_section.dart';

/// Section showing items watched on other devices (cross-device continuity).
///
/// Displays items from the watch history that were last watched on a
/// different device, allowing users to continue playback seamlessly.
class CrossDeviceSection extends ConsumerWidget {
  const CrossDeviceSection({super.key, required this.items});

  final List<WatchHistoryEntry> items;

  /// Truncates device name to fit in badge.
  String _truncateDeviceName(String name) {
    if (name.length <= 10) return name;
    return '${name.substring(0, 8)}…';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final vodItems = items.map((e) => e.toVodItem()).toList();

    // Calculate 16:9 landscape dimensions based on screen width
    final w = MediaQuery.sizeOf(context).width;
    final cardW = watchHistoryCardWidth(w);
    final cardH = cardW * 9 / 16;
    final sectionH =
        cardH + (CrispySpacing.md * 2) + kWatchHistorySectionPadding;

    return VodRow(
      title: 'Continue on this device',
      icon: Icons.devices,
      items: vodItems,
      cardWidth: cardW,
      cardHeight: cardH,
      sectionHeight: sectionH,
      // Provide custom tap action to inject startPosition
      customOnTap: (ctx, vodItem, heroTag) {
        final item = items.firstWhereOrNull((e) => e.id == vodItem.id);
        if (item == null) return;
        ref
            .read(playbackSessionProvider.notifier)
            .startPlayback(
              streamUrl: item.streamUrl,
              channelName: item.name,
              isLive: false,
              startPosition: Duration(milliseconds: item.positionMs),
              posterUrl: item.posterUrl,
              seriesPosterUrl: item.seriesPosterUrl,
              mediaType: item.mediaType,
              seriesId: item.seriesId,
              seasonNumber: item.seasonNumber,
              episodeNumber: item.episodeNumber,
            );
      },
      // Build the device name badge and dismiss button
      overlayBuilder: (ctx, vodItem) {
        final item = items.firstWhereOrNull((e) => e.id == vodItem.id);
        if (item == null) return const SizedBox.shrink();
        final progress = item.progress;

        return WatchHistoryCardOverlay(
          onDismiss:
              () => ref.read(watchHistoryServiceProvider).delete(item.id),
          progress: progress,
          progressColor: colorScheme.tertiary,
          progressMinHeight: 3.0,
          badge:
              item.deviceName != null
                  ? Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiary,
                        borderRadius: BorderRadius.circular(CrispyRadius.none),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.devices,
                            size: 10,
                            color: colorScheme.onTertiary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _truncateDeviceName(item.deviceName!),
                            style: TextStyle(
                              fontSize: 8,
                              color: colorScheme.onTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : null,
        );
      },
    );
  }
}
