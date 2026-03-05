// FE-PS-07: Playback queue / watch-next panel
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../providers/osd_providers.dart';
import '../providers/player_providers.dart';

// ─────────────────────────────────────────────────────────────
//  Queue item model
// ─────────────────────────────────────────────────────────────

/// A single item in the playback queue.
@immutable
class QueueItem {
  const QueueItem({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.duration,
    this.subtitle,
  });

  /// Unique identifier (episode id, channel id, etc.).
  final String id;

  /// Display title.
  final String title;

  /// Optional subtitle (e.g., episode number or channel name).
  final String? subtitle;

  /// Optional thumbnail URL.
  final String? thumbnailUrl;

  /// Optional content duration.
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QueueItem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────
//  Queue provider (FE-PS-07)
// ─────────────────────────────────────────────────────────────

/// State for the playback queue.
@immutable
class QueueState {
  const QueueState({
    this.items = const [],
    this.currentIndex = 0,
    this.isVisible = false,
    this.label = 'Up Next',
  });

  /// Ordered list of upcoming items (index 0 = next to play).
  final List<QueueItem> items;

  /// Index of the currently playing item in [items].
  final int currentIndex;

  /// Whether the queue panel is open.
  final bool isVisible;

  /// Panel heading (e.g. "Up Next", "Season 2 Episodes").
  final String label;

  QueueState copyWith({
    List<QueueItem>? items,
    int? currentIndex,
    bool? isVisible,
    String? label,
  }) {
    return QueueState(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      isVisible: isVisible ?? this.isVisible,
      label: label ?? this.label,
    );
  }
}

/// Manages the playback queue state.
class QueueNotifier extends Notifier<QueueState> {
  @override
  QueueState build() => const QueueState();

  /// Populates the queue with [items] and an optional [label].
  ///
  /// Call this when loading a series season, EPG schedule,
  /// or a playlist.
  ///
  /// TODO(FE-PS-07): Wire to series/EPG/playlist providers so
  /// the queue auto-populates from backend data.
  void setQueue({
    required List<QueueItem> items,
    int currentIndex = 0,
    String label = 'Up Next',
  }) {
    state = state.copyWith(
      items: items,
      currentIndex: currentIndex,
      label: label,
    );
  }

  /// Clears the queue.
  void clear() => state = const QueueState();

  /// Shows or hides the queue panel.
  void toggleVisibility() =>
      state = state.copyWith(isVisible: !state.isVisible);

  /// Opens the queue panel.
  void show() => state = state.copyWith(isVisible: true);

  /// Closes the queue panel.
  void hide() => state = state.copyWith(isVisible: false);

  /// Advances [currentIndex] to the next item.
  void advance() {
    if (state.currentIndex < state.items.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }
}

/// Global queue provider.
final queueProvider = NotifierProvider<QueueNotifier, QueueState>(
  QueueNotifier.new,
);

// ─────────────────────────────────────────────────────────────
//  Queue panel overlay (FE-PS-07)
// ─────────────────────────────────────────────────────────────

/// Slide-in queue panel (right side, 320 dp wide).
///
/// Shows upcoming items for:
/// - **Series**: next episodes from the same season.
/// - **Channels**: upcoming EPG entries.
/// - **Playlists**: remaining playlist items.
///
/// Add a "Queue" button to the OSD overflow menu (or top bar)
/// that calls `ref.read(queueProvider.notifier).toggleVisibility()`.
class PlayerQueueOverlay extends ConsumerWidget {
  const PlayerQueueOverlay({required this.onSkipTo, super.key});

  /// Called when the user taps a queue item.
  ///
  /// [item] is the selected [QueueItem].
  final ValueChanged<QueueItem> onSkipTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSlide(
      offset: queue.isVisible ? Offset.zero : const Offset(1.0, 0.0),
      duration: CrispyAnimation.normal,
      curve:
          queue.isVisible
              ? CrispyAnimation.enterCurve
              : CrispyAnimation.exitCurve,
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 320,
          child: _QueuePanel(
            queue: queue,
            colorScheme: colorScheme,
            onSkipTo: onSkipTo,
            onClose: () => ref.read(queueProvider.notifier).hide(),
          ),
        ),
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({
    required this.queue,
    required this.colorScheme,
    required this.onSkipTo,
    required this.onClose,
  });

  final QueueState queue;
  final ColorScheme colorScheme;
  final ValueChanged<QueueItem> onSkipTo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(
        top: CrispySpacing.xxl,
        bottom: CrispySpacing.xxl,
        right: CrispySpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CrispySpacing.md,
              CrispySpacing.md,
              CrispySpacing.xs,
              CrispySpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  color: colorScheme.onSurface,
                  size: 18,
                ),
                const SizedBox(width: CrispySpacing.sm),
                Expanded(
                  child: Text(
                    queue.label,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: colorScheme.onSurface,
                    size: 18,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: const EdgeInsets.all(CrispySpacing.xs),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Item list ───────────────────────────────────────
          if (queue.items.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Queue is empty',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: CrispySpacing.xs),
                itemCount: queue.items.length,
                itemBuilder: (context, i) {
                  final item = queue.items[i];
                  final isCurrent = i == queue.currentIndex;
                  final isUpcoming = i > queue.currentIndex;

                  return Opacity(
                    opacity: isUpcoming || isCurrent ? 1.0 : 0.45,
                    child: _QueueItemTile(
                      item: item,
                      isCurrent: isCurrent,
                      colorScheme: colorScheme,
                      onTap:
                          isUpcoming || isCurrent ? () => onSkipTo(item) : null,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  const _QueueItemTile({
    required this.item,
    required this.isCurrent,
    required this.colorScheme,
    this.onTap,
  });

  final QueueItem item;
  final bool isCurrent;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  String? _formatDuration(Duration? d) {
    if (d == null) return null;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final durationLabel = _formatDuration(item.duration);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.sm,
        ),
        decoration:
            isCurrent
                ? BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                  border: Border(
                    left: BorderSide(color: colorScheme.primary, width: 3),
                  ),
                )
                : null,
        child: Row(
          children: [
            // Thumbnail
            _QueueThumbnail(
              thumbnailUrl: item.thumbnailUrl,
              isCurrent: isCurrent,
              colorScheme: colorScheme,
            ),

            const SizedBox(width: CrispySpacing.sm),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: textTheme.bodySmall?.copyWith(
                      color:
                          isCurrent
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (durationLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      durationLabel,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Play indicator for current, chevron for upcoming
            if (isCurrent)
              Icon(
                Icons.play_arrow_rounded,
                color: colorScheme.primary,
                size: 18,
              )
            else if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _QueueThumbnail extends StatelessWidget {
  const _QueueThumbnail({
    required this.thumbnailUrl,
    required this.isCurrent,
    required this.colorScheme,
  });

  final String? thumbnailUrl;
  final bool isCurrent;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    const w = 72.0;
    const h = 40.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(CrispyRadius.tv),
      child: SizedBox(
        width: w,
        height: h,
        child:
            thumbnailUrl != null
                ? Image.network(
                  thumbnailUrl!,
                  width: w,
                  height: h,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) =>
                          _PlaceholderThumb(colorScheme: colorScheme),
                )
                : _PlaceholderThumb(colorScheme: colorScheme),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.surfaceContainerHigh,
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: colorScheme.onSurface.withValues(alpha: 0.3),
        size: 20,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  OSD Queue button (FE-PS-07)
// ─────────────────────────────────────────────────────────────

/// Compact icon button for the OSD bar that toggles the queue
/// panel. Only shown when the queue has items.
class OsdQueueButton extends ConsumerWidget {
  const OsdQueueButton({this.order, super.key});

  /// Focus traversal order within the OSD bar.
  final double? order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasItems = ref.watch(queueProvider.select((s) => s.items.isNotEmpty));
    if (!hasItems) return const SizedBox.shrink();

    final isVisible = ref.watch(queueProvider.select((s) => s.isVisible));

    Widget button = Tooltip(
      message: isVisible ? 'Close Queue' : 'Queue',
      child: IconButton(
        onPressed: () {
          ref.read(queueProvider.notifier).toggleVisibility();
          // Keep OSD visible while queue is open.
          ref.read(osdStateProvider.notifier).show();
        },
        icon: Icon(
          Icons.queue_rounded,
          color:
              isVisible ? Theme.of(context).colorScheme.primary : Colors.white,
          size: 22,
        ),
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.2);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.1);
            }
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: Colors.white, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
    );

    if (order != null) {
      button = FocusTraversalOrder(
        order: NumericFocusOrder(order!),
        child: button,
      );
    }

    return button;
  }
}
