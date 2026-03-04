import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/skeleton_loader.dart';

/// Returns the appropriate channel-list sliver for a given
/// loading/error/empty state.
///
/// Usage:
/// ```dart
/// channelStateSliver(isLoading: s.isLoading, error: s.error)
///   ?? _channelSliver(s.filteredChannels),
/// ```
Widget? channelStateSliver({
  required bool isLoading,
  String? error,
  bool isEmpty = false,
}) {
  if (isLoading) return const ChannelSkeletonSliver();
  if (error != null) return ChannelErrorSliver(error: error);
  if (isEmpty) return const ChannelEmptySliver();
  return null;
}

/// Skeleton loading sliver for the channel list.
class ChannelSkeletonSliver extends StatelessWidget {
  const ChannelSkeletonSliver({super.key, this.itemCount = 12});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.xs,
          ),
          child: SkeletonLine(width: double.infinity),
        ),
        childCount: itemCount,
      ),
    );
  }
}

/// Error state sliver for channel list load failures.
class ChannelErrorSliver extends StatelessWidget {
  const ChannelErrorSliver({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: CrispySpacing.md),
            Text(
              'Failed to load channels',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: CrispySpacing.sm),
            Text(error, style: TextStyle(color: colorScheme.error)),
          ],
        ),
      ),
    );
  }
}

/// Empty state sliver when no channels are found.
class ChannelEmptySliver extends StatelessWidget {
  const ChannelEmptySliver({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverFillRemaining(
      child: EmptyStateWidget(
        icon: Icons.live_tv,
        title: 'No channels found',
        description: 'Add a playlist source in Settings',
        showSettingsButton: true,
      ),
    );
  }
}
