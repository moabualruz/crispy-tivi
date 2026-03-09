// FE-PS-02: Chapter markers on seek bar
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/duration_formatter.dart';
import 'seek_bar_with_preview.dart';

// ─────────────────────────────────────────────────────────────
//  Chapter data model
// ─────────────────────────────────────────────────────────────

/// A single chapter in a video file.
///
/// [start] is the chapter start position. [end] is exclusive
/// (next chapter start, or total duration for the last chapter).
@immutable
class VideoChapter {
  const VideoChapter({
    required this.title,
    required this.start,
    required this.end,
  });

  /// Chapter title (e.g. "Chapter 1" or "Opening Credits").
  final String title;

  /// Chapter start position.
  final Duration start;

  /// Chapter end position (exclusive).
  final Duration end;

  /// Whether [position] falls inside this chapter.
  bool containsPosition(Duration position) =>
      position >= start && position < end;

  /// Chapter duration.
  Duration get duration => end - start;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoChapter &&
          title == other.title &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(title, start, end);
}

// ─────────────────────────────────────────────────────────────
//  Chapter provider (FE-PS-02)
// ─────────────────────────────────────────────────────────────

/// Holds the chapter list for the currently playing video.
///
/// Chapters are populated from media_kit track metadata when
/// available. Empty list means no chapter info.
///
/// Waiting on upstream: Parse chapters from media_kit
/// `player.state.tracks` metadata once media_kit exposes
/// chapter tracks — see media_kit issue #806.
final chapterListProvider =
    NotifierProvider<ChapterListNotifier, List<VideoChapter>>(
      ChapterListNotifier.new,
    );

/// Notifier managing the chapter list.
class ChapterListNotifier extends Notifier<List<VideoChapter>> {
  @override
  List<VideoChapter> build() => const [];

  /// Replaces the chapter list (called when a new media item loads).
  void setChapters(List<VideoChapter> chapters) => state = chapters;

  /// Clears chapters (called when playback stops).
  void clear() => state = const [];
}

// ─────────────────────────────────────────────────────────────
//  Chapter-aware seek bar (FE-PS-02)
// ─────────────────────────────────────────────────────────────

/// Drop-in replacement for [SeekBarWithPreview] that adds:
///
/// - Thin white tick marks at chapter boundaries.
/// - Tooltip showing chapter name on hover near a tick.
/// - "Chapters" icon button that opens [ChapterListSheet].
///
/// When no chapters are available the widget behaves
/// identically to a plain [SeekBarWithPreview].
class PlayerSeekBar extends ConsumerStatefulWidget {
  const PlayerSeekBar({
    required this.progress,
    required this.duration,
    required this.onSeek,
    this.bufferProgress = 0.0,
    this.bufferRanges,
    this.accentColor,
    super.key,
  });

  final double progress;
  final double bufferProgress;
  final List<(double start, double end)>? bufferRanges;
  final Duration duration;
  final ValueChanged<double> onSeek;
  final Color? accentColor;

  @override
  ConsumerState<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends ConsumerState<PlayerSeekBar> {
  double? _hoverX;
  double _barWidth = 0.0;

  /// Returns the chapter whose tick is closest to [hoverX]
  /// within a 16 px snap radius, or null if none is near.
  VideoChapter? _chapterNearHover(List<VideoChapter> chapters, double hoverX) {
    if (_barWidth <= 0) return null;
    for (final ch in chapters) {
      if (widget.duration.inMilliseconds == 0) continue;
      final frac = ch.start.inMilliseconds / widget.duration.inMilliseconds;
      final tickX = frac * _barWidth;
      if ((tickX - hoverX).abs() <= 16) return ch;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final chapters = ref.watch(chapterListProvider);
    final hasChapters = chapters.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Seek bar + chapter tick overlay ──────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            _barWidth = constraints.maxWidth;
            return MouseRegion(
              onHover: (e) => setState(() => _hoverX = e.localPosition.dx),
              onExit: (_) => setState(() => _hoverX = null),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Underlying seek bar
                  SeekBarWithPreview(
                    progress: widget.progress,
                    bufferProgress: widget.bufferProgress,
                    bufferRanges: widget.bufferRanges,
                    duration: widget.duration,
                    onSeek: widget.onSeek,
                    accentColor: widget.accentColor,
                  ),

                  // Chapter tick marks
                  if (hasChapters && _barWidth > 0)
                    Positioned.fill(
                      child: _ChapterTickOverlay(
                        chapters: chapters,
                        duration: widget.duration,
                        barWidth: _barWidth,
                      ),
                    ),

                  // Chapter hover tooltip
                  if (hasChapters && _hoverX != null)
                    _ChapterHoverTooltip(
                      chapter: _chapterNearHover(chapters, _hoverX!),
                      hoverX: _hoverX!,
                      barWidth: _barWidth,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Chapter tick overlay (FE-PS-02)
// ─────────────────────────────────────────────────────────────

/// Draws thin white vertical tick marks at each chapter start
/// position on the seek bar track area.
class _ChapterTickOverlay extends StatelessWidget {
  const _ChapterTickOverlay({
    required this.chapters,
    required this.duration,
    required this.barWidth,
  });

  final List<VideoChapter> chapters;
  final Duration duration;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    if (duration.inMilliseconds == 0) return const SizedBox.shrink();

    return CustomPaint(
      painter: _ChapterTickPainter(
        chapters: chapters,
        totalMs: duration.inMilliseconds.toDouble(),
        barWidth: barWidth,
      ),
    );
  }
}

class _ChapterTickPainter extends CustomPainter {
  _ChapterTickPainter({
    required this.chapters,
    required this.totalMs,
    required this.barWidth,
  });

  final List<VideoChapter> chapters;
  final double totalMs;
  final double barWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.75)
          ..strokeWidth = 2
          ..style = PaintingStyle.fill;

    // Skip the first chapter (tick at 0 would overlap the
    // start of the bar).
    for (final ch in chapters.skip(1)) {
      final frac = ch.start.inMilliseconds / totalMs;
      final x = frac * barWidth;
      // Draw a small rect: 2px wide, centred on track.
      final rect = Rect.fromLTWH(x - 1, size.height / 2 - 6, 2, 12);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_ChapterTickPainter old) =>
      old.chapters != chapters ||
      old.totalMs != totalMs ||
      old.barWidth != barWidth;
}

// ─────────────────────────────────────────────────────────────
//  Chapter hover tooltip (FE-PS-02)
// ─────────────────────────────────────────────────────────────

class _ChapterHoverTooltip extends StatelessWidget {
  const _ChapterHoverTooltip({
    required this.chapter,
    required this.hoverX,
    required this.barWidth,
  });

  final VideoChapter? chapter;
  final double hoverX;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    if (chapter == null) return const SizedBox.shrink();

    const tooltipWidth = 140.0;
    final clampedX = hoverX.clamp(
      tooltipWidth / 2,
      barWidth - tooltipWidth / 2,
    );

    return Positioned(
      left: clampedX - tooltipWidth / 2,
      bottom: CrispySpacing.xl,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: CrispyAnimation.fast,
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.sm,
            vertical: CrispySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: CrispyColors.scrimFull,
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
          ),
          child: Text(
            chapter!.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Chapter list modal bottom sheet (FE-PS-02)
// ─────────────────────────────────────────────────────────────

/// Modal bottom sheet listing all chapters.
///
/// Tapping a chapter seeks to its start position.
class ChapterListSheet extends ConsumerWidget {
  const ChapterListSheet({required this.onSeek, super.key});

  /// Callback with a progress fraction (0.0–1.0) when a chapter
  /// is selected.
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(chapterListProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(CrispyRadius.tv),
              topRight: Radius.circular(CrispyRadius.tv),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: CrispySpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                  vertical: CrispySpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.list_rounded,
                      color: colorScheme.onSurface,
                      size: 20,
                    ),
                    const SizedBox(width: CrispySpacing.sm),
                    Text(
                      'Chapters',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Chapter list
              Expanded(
                child:
                    chapters.isEmpty
                        ? Center(
                          child: Text(
                            'No chapters available',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        )
                        : ListView.builder(
                          controller: controller,
                          itemCount: chapters.length,
                          itemBuilder: (context, i) {
                            final ch = chapters[i];
                            return _ChapterListTile(
                              chapter: ch,
                              index: i,
                              onTap: () {
                                Navigator.of(context).pop();
                                // Calculate progress fraction
                                final totalDuration = chapters.last.end;
                                if (totalDuration.inMilliseconds > 0) {
                                  final frac =
                                      ch.start.inMilliseconds /
                                      totalDuration.inMilliseconds;
                                  onSeek(frac.clamp(0.0, 1.0));
                                }
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChapterListTile extends StatelessWidget {
  const _ChapterListTile({
    required this.chapter,
    required this.index,
    required this.onTap,
  });

  final VideoChapter chapter;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        chapter.title,
        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DurationFormatter.clock(chapter.start),
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}

/// Shows the chapter list bottom sheet.
///
/// Usage:
/// ```dart
/// showChapterListSheet(context, onSeek: (frac) => player.seek(frac));
/// ```
void showChapterListSheet(
  BuildContext context, {
  required ValueChanged<double> onSeek,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChapterListSheet(onSeek: onSeek),
  );
}
