import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/alpha_jump_bar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_boundary.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../domain/entities/channel.dart';
import 'channel_grid_item.dart';

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
  VoidCallback? onRetry,
}) {
  if (isLoading) return const ChannelSkeletonSliver();
  if (error != null) {
    return ChannelErrorSliver(error: error, onRetry: onRetry);
  }
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
  const ChannelErrorSliver({super.key, required this.error, this.onRetry});

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: ErrorBoundary(error: error, onRetry: onRetry ?? () {}),
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

extension AsyncValueValueOrNull<T> on AsyncValue<T> {
  T? get valueOrNull =>
      when(data: (value) => value, loading: () => null, error: (_, _) => null);
}

class ChannelCard extends StatelessWidget {
  const ChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.currentProgram,
    this.isPlaying = false,
    this.autofocus = false,
  });

  final Channel channel;
  final VoidCallback onTap;
  final String? currentProgram;
  final bool isPlaying;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return ChannelGridItem(
      channel: channel,
      onTap: onTap,
      currentProgram: currentProgram,
      isPlaying: isPlaying,
      autofocus: autofocus,
    );
  }
}

class ChannelCardSkeleton extends StatelessWidget {
  const ChannelCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(CrispySpacing.sm),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: SkeletonLoader(width: 72, height: 48, borderRadius: 12),
            ),
          ),
          SizedBox(height: CrispySpacing.xs),
          SkeletonLine(width: 72, height: 10),
        ],
      ),
    );
  }
}

/// Adapter that converts index-based offsets to pixel offsets
/// once the scroll controller's max extent is known.
class AlphaJumpBarAdapter extends StatefulWidget {
  final ScrollController scrollController;
  final Map<String, double> indexOffsets;
  final int totalItemCount;

  const AlphaJumpBarAdapter({
    super.key,
    required this.scrollController,
    required this.indexOffsets,
    required this.totalItemCount,
  });

  @override
  State<AlphaJumpBarAdapter> createState() => _AlphaJumpBarAdapterState();
}

class _AlphaJumpBarAdapterState extends State<AlphaJumpBarAdapter> {
  Map<String, double> _pixelOffsets = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(AlphaJumpBarAdapter old) {
    super.didUpdateWidget(old);
    if (old.indexOffsets != widget.indexOffsets ||
        old.totalItemCount != widget.totalItemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  bool _extentReady = false;

  void _onScroll() {
    if (!_extentReady && widget.scrollController.hasClients) {
      _update();
    }
  }

  void _update() {
    if (!widget.scrollController.hasClients) return;
    final maxExtent = widget.scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    _extentReady = true;
    final scaled = AlphaJumpBar.scaleOffsets(
      widget.indexOffsets,
      maxExtent,
      widget.totalItemCount,
    );
    if (mounted) setState(() => _pixelOffsets = scaled);
  }

  @override
  Widget build(BuildContext context) {
    return AlphaJumpBar(
      controller: widget.scrollController,
      sectionOffsets: _pixelOffsets,
      totalItemCount: widget.totalItemCount,
    );
  }
}
